# Building an image

Buildroot needs a native Linux filesystem — symlinks, permissions, case
sensitivity. A Windows bind mount does not reliably provide them, so the build runs
entirely inside a **Docker named volume**. Nothing touches `C:` except copying the
finished `.img` out.

```powershell
# once
cd seedsigner-os ; docker build -t ssos-builder . ; docker volume create ssbuild

# copy the repos into the volume and init the buildroot submodule
docker run --rm -v ssbuild:/work -v "${PWD}/..:/src:ro" `
  -v "${PWD}/../build:/s:ro" --entrypoint bash ssos-builder /s/stage.sh

# build (45 min from cold; ccache makes rebuilds much faster)
docker run -d --name ssos-pi0 -v ssbuild:/work -v "${PWD}/../build:/s:ro" `
  --entrypoint bash ssos-builder /s/build-pi0.sh
docker logs -f ssos-pi0

# verify, then copy out
docker run --rm -v ssbuild:/work -v "${PWD}/../build:/s:ro" --entrypoint bash ssos-builder /s/verify.sh
docker run --rm -v ssbuild:/work -v "${PWD}/../build:/s:ro" --entrypoint bash ssos-builder /s/verify-img.sh
```

Re-run `stage.sh` after any change to either repo — it copies the working trees in.

## Two things that will bite you

**`--app-repo` and `--app-branch` only parse as `--flag=value`.** The help text
prints them bare and the parser rejects that form outright. We use them to point at
the **local** fork in the volume. `build.sh` clones the branch from it, so the image gets the **committed** head of `seedkeeper-support`: commit app changes before building, or they are silently left out. Check `version.json` in the built image.

Do not reach for `--skip-repo` instead: it skips `download_app_repo`, which also
compiles the translations, and it leaves `version.json` unwritten. A missing
`version.json` makes the app raise at the splash screen — the build succeeds and the
device does not boot.

**Stock's `Config.in` files have no trailing newline.** Appending a `source` line
concatenates it onto the last existing one and buildroot dies with a syntax error at
that line. Check for it after editing:

```bash
grep -n 'Config.in"source' opt/*/Config.in
```

## Verification

`verify.sh` inspects the built rootfs; `verify-img.sh` reads `config.txt` straight
out of the FAT partition of the finished `.img` — the artefact that actually gets
flashed rather than a staging directory. Prefer the second when the two disagree.

Between them they check: pysatochip / pyscard / pygp present, `libccidtwin.so` and
`pcscd` present, the reader config pointing at `/dev/ttyAMA0`, the bundled applets
matching their hashes, `version.json` written, the four required `config.txt`
settings, and **no brcm firmware blobs anywhere in the rootfs**.

That last one is the point: "there is no radio" is the most important claim this
image makes, so it fails loudly rather than being believed.

## The checks that run things rather than read them

Static "is it present" checks have passed while the device did not work more
often than the images have been wrong. These four execute something:

| Script | What it actually does |
|---|---|
| `verify-imports.sh` | imports each module with the target's ARM python under qemu |
| `verify-crypto.sh` | runs FIPS 81 / FIPS 197 / RFC 4493 / RFC 2202 vectors |
| `verify-reader.sh` | starts `pcscd` both foreground *and* daemonised, and asserts `CONFIG_UNIX=y` |
| `verify-seed-layout.sh` | saves a seed and reads it back through `export_mnemonic` |

The last two exist because of faults that shipped. pcscd died in
`InitializeSocket()` on pi0 for three builds because the kernel had no AF_UNIX
and every check ran on the build host's kernel, which has it.

`verify-seed-layout.sh` guards the worst failure mode in the project: a wrong
byte in the secret layout breaks nothing visible. The card accepts it, the write
reports success, and it is discovered only by someone trying to restore a wallet
from a backup that cannot be read. Run it against the target rootfs, not the
host - the entropy and master seed come from embit, and it is the *shipped*
embit that has to agree.

All six, after a build:

```powershell
foreach ($s in "verify.sh","verify-img.sh","verify-app.sh",`
               "verify-imports.sh","verify-crypto.sh","verify-reader.sh",`
               "verify-seed-layout.sh") {
  docker run --rm --privileged -v ssbuild:/work -v "${PWD}/../build:/s:ro" `
    --entrypoint bash ssos-builder /s/$s
}
```

`verify-reader.sh` and `verify-seed-layout.sh` need `--privileged` (bind-mounting
`/dev` into the chroot, and qemu).
