# SeedKeeper support on stock SeedSigner

Two features from [3rdIteration/seedsigner](https://github.com/3rdIteration/seedsigner)
ported onto **stock** SeedSigner, and nothing else:

1. **SeedKeeper import** — load a seed from a SeedKeeper card.
2. **DIY Tools → Install Applet** — flash the SeedKeeper Javacard applet, from
   `.cap` files bundled in the image.

Reader hardware: **SEC1210 smartcard hat only**, structured so PN532 NFC can be
added later without rework.

## Layout

```
seedsigner-seedkeeper/
  seedsigner/       fork of SeedSigner/seedsigner       branch: seedkeeper-support
  seedsigner-os/    fork of SeedSigner/seedsigner-os    branch: seedkeeper-support
```

Both have `3rditeration` as a second remote, for reference and cherry-picking. We
track stock as `origin` so upstream stays mergeable — that is the whole point of
porting two features rather than adopting the fork.

## Why port rather than fork 3rdIteration

3rdIteration is **566 commits and +158,507 lines** ahead of stock on the app, plus
152 commits on the OS. It is a large, capable project, but adopting it wholesale
means inheriting GPG tooling, SLIP39, AEZEED, BIP38/WIF, Passport/BitBox/TapSigner
backups, KeyCard, Specter-DIY, MicroSD flashing tools and desktop simulation — on a
device whose security case rests on being small and auditable.

We want two features. Porting them keeps the delta reviewable.

---

## What has to come across

### App (`seedsigner/`)

The hard part. `smartcard_views.py` in the fork is **6,309 lines across 60 view
classes** and contains *every* smartcard feature. Ours are ~14 of those classes,
sitting on shared plumbing that is interleaved with features we do not want.

This is a dissection, not a cherry-pick.

| Piece | Source | Notes |
|---|---|---|
| Card connection + PIN | `helpers/seedkeeper_utils.py` (738 lines) | Mostly intact — it *is* the connection layer |
| SeedKeeper views | `views/smartcard_views.py`, `ToolsSeedkeeper*` | Extract from the 60-class file |
| DIY install views | `views/smartcard_views.py`, `ToolsSatochipDIYView`, `ToolsDIYInstallAppletView`, `ToolsDIYUninstallAppletView` | Same file |
| Seed import entry | `views/seed_views.py` `LoadSeedView.IMPORT_SEEDKEEPER` | One menu option + branch |
| Settings | `models/settings_definition.py` | `SMARTCARD_SUPPORT`, `SMARTCARD_INTERFACES`, `CACHE_SCARD_PIN`, `SCARD_PIN_ATTEMPTS` |
| Controller state | `controller.py` | `Satochip_Connector`, `Satochip_PIN`, `Satochip_Last_UID_SHA1` |
| Applet binaries | `javacard-cap/` | See bundling, below |

**Explicitly not ported:** Satochip card ops, KeyCard, Specter-DIY, SmartPGP/GPG,
SLIP39, AEZEED, BIP38/WIF, encrypted QR, Passport/BitBox/TapSigner backups, MicroSD
flashing, desktop simulation, entropy monitor, `io_config`.

### OS (`seedsigner-os/`)

Mechanical. The fork's smartcard defconfig pulls **14 packages**; we need **four**:

| Package | Why |
|---|---|
| `python-pysatochip` | SeedKeeper protocol |
| `python-pyscard` | PC/SC bindings (needs `host-swig`) |
| `python-pygp` | GlobalPlatform — the applet install |
| `ccid-sec1210` | CCID built with `-Dserial=true` for the serial reader |

Dropped: `keycard-py`, `specter-card`, `shamir-mnemonic`, `ndeflib`, `mnemonic`,
`pgpy`, `smartpgp`, `ifdnfc`, `nfc-bindings`, `openct`, `libcamera-config`,
`opencv4-config`, `picamera2`.

Also needed:

- `etc/reader.conf.d/sec1210` — points pcsc-lite at `/dev/ttyAMA0:SEC1210URT` via
  `libccidtwin.so`
- `etc/init.d/S01pcscd` — starts pcscd
- Boot config: **`dtoverlay=disable-bt`**, `dtoverlay=disable-wifi`,
  `dtoverlay=mmc`

`S00smartcard` is **not** needed — it only activates IFD-NFC. It comes back with
PN532.

---

## The UART, and why it lines up with the no-radio requirement

The SEC1210 is a **serial** reader on `/dev/ttyAMA0` — the PL011 UART. On Pi Zero W,
Zero 2 W and Pi 3+ that UART is wired to Bluetooth by default, so
**`dtoverlay=disable-bt` is functionally required** for the reader to work at all,
not merely a hardening choice.

That is a happy alignment: no-radio is both the security posture we want and a
precondition for the hardware. On a Pi Zero 1.3 there is no radio to disable, but
the serial console must still not claim the UART.

---

## Bundling the applets

`ToolsDIYInstallAppletView` reads `.cap` files from two places and merges them:

- **Internal:** `_get_internal_cap_dir()` = `Path(__file__).parents[3] / "javacard-cap"`.
  The app lives at `/opt/src/seedsigner/…` in the image, so this resolves to
  **`/opt/javacard-cap/`**.
- **MicroSD:** `<microsd>/javacard-cap/`.

Because `seedsigner-os`'s `build.sh` clones the app repo into `rootfs-overlay/opt/`,
putting `javacard-cap/` at the **app repo root** lands it at `/opt/javacard-cap/`
automatically. No OS-side change is needed to bundle — and `build.sh`'s trim list
does not touch that directory.

We bundle **SeedKeeper only**:

| File | Size | SHA256 (verified against upstream manifest) |
|---|---|---|
| `SeedKeeper-0.2-official.cap` | 93,554 | `28dbae3c…03dabcd` |
| `SeedKeeper-Ndef-v0.2-0.1.cap` | 125,154 | `ef776360…aa632c9b` |

~219 KB against a 50 MB image. Adding another applet later is dropping in a file.

**These are third-party binaries being flashed onto a card that will hold keys.**
Keep `javacard-cap.sha256` alongside them, keep provenance recorded, and re-verify
on any update. Both files above were checked against the upstream manifest at import
time and matched.

---

## Supply chain to be aware of

`python-pysatochip` and `python-pygp` are built from **3rdIteration's own forks**
(`3rdIteration/pysatochip@0.6a`, `3rdIteration/PyGP@0.2a`), not from upstream
Satochip or PyPI. Porting only two features does not escape that dependency — it is
inherent to talking to these cards with this code.

Options, in increasing order of effort: pin the exact commits and vendor the
tarballs; review the diff against upstream pysatochip; or write a minimal protocol
implementation. Pinning is the sane default; note the decision here when made.

---

## Order of work

1. **OS first** — four packages, reader config, pcscd, boot config. Well-defined and
   independently verifiable: build an image and check `pcsc_scan` sees the reader.
2. **App: connection layer** — `seedkeeper_utils.py` and settings, with no UI.
3. **App: SeedKeeper import** — the smaller feature and the one with a clear test.
4. **App: DIY install** — needs `pygp` and a card you are willing to write to.
5. **Bundle the caps** and verify the hashes at build time.

Do not attempt 2-4 before 1 works on real hardware. Without a reader the app changes
cannot be exercised at all.
