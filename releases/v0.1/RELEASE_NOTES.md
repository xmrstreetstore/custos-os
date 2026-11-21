# Custos OS v0.1 (beta)

First public release. A SeedSigner build for the Raspberry Pi Zero v1.3 that loads
and saves seeds on SeedKeeper smartcards, by contact (SEC1210 HAT) or NFC (PN532).

## Download and verify

Checking the download takes about five minutes. It proves the image is exactly the one
we built and signed, and that nobody swapped it on the way to you. This device will
hold your seed, so please don't skip it.

### Step 1. Install GPG (only once)

- **Windows:** install [Gpg4win](https://gpg4win.org) with the default options.
- **macOS:** install [GPG Suite](https://gpgtools.org), or run `brew install gnupg`.
- **Linux:** GPG is usually installed already. If not: `sudo apt install gnupg`.

### Step 2. Download the files

Scroll down to **Assets** on this page and download these into the same folder,
for example your Downloads folder:

| File | What it is |
|---|---|
| `custos.pi0.img` (50 MB) | The image you will flash |
| `SHA256SUMS` | The image's fingerprint (checksum) |
| `SHA256SUMS.asc` | Our signature on that checksum |
| `SHA256SUMS.sig` | The same signature in binary form. You need only one of the two. |

### Step 3. Open a terminal in that folder

- **Windows:** open **PowerShell** and type `cd $HOME\Downloads`
- **macOS / Linux:** open **Terminal** and type `cd ~/Downloads`

### Step 4. Import our signing key

Type this (the same on every system):

```
gpg --keyserver hkps://keys.openpgp.org --recv-keys E8C0F756E61138137DFF39BEF1FD97FD5D2AAA2C
```

It should say `public key "xmrstreetstore <info@xmrstreet.store>" imported`.
The same key is also published at [github.com/xmrstreetstore.gpg](https://github.com/xmrstreetstore.gpg),
[custos-os.com](https://custos-os.com/xmrstreetstore.asc), keyserver.ubuntu.com and
[in the repo](https://github.com/xmrstreetstore/custos-os/blob/master/keys/xmrstreetstore.asc),
so you can compare its fingerprint across sources.

### Step 5. Check the signature

```
gpg --verify SHA256SUMS.asc SHA256SUMS
```

If you downloaded `SHA256SUMS.sig` instead, type `gpg --verify SHA256SUMS.sig SHA256SUMS`.

You must see **both** of these lines:

```
Good signature from "xmrstreetstore <info@xmrstreet.store>"
Primary key fingerprint: E8C0 F756 E611 3813 7DFF  39BE F1FD 97FD 5D2A AA2C
```

A warning that the key "is not certified with a trusted signature" is normal. It only
means you have not signed our key yourself.

> [!CAUTION]
> **Stop** if it says `BAD signature`, or if the fingerprint is different. Do not use the image.

### Step 6. Check the image

- **Linux:** `sha256sum -c SHA256SUMS` must print `custos.pi0.img: OK`
- **macOS:** `shasum -a 256 -c SHA256SUMS` must print `custos.pi0.img: OK`
- **Windows (PowerShell):** this must print `True`:
  ```
  (Get-FileHash custos.pi0.img).Hash -eq (Get-Content SHA256SUMS).Split(' ')[0]
  ```

> [!CAUTION]
> **Stop** if you get anything else. Delete the files and download them again.

For reference, the image's SHA256 is
`f1993c7963f4bf5d96d7f86bc55c362cfb9acfa6b82fb38704cb9c522da8bb2b`.

### Step 7. Flash the microSD card

1. Open [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (or
   [balenaEtcher](https://etcher.balena.io)).
2. In Raspberry Pi Imager, choose **Choose OS → Use custom** and pick `custos.pi0.img`.
3. Choose your microSD card and write it. If it asks to apply OS customisation
   settings, choose **No**.
4. Put the card in the Raspberry Pi Zero v1.3 and power it on.

## Built from

| Repo | Tag | Commit |
|---|---|---|
| custos-seedsigner | `v0.1` | `d42afed8` |
| custos-seedsigner-os | `v0.1` | `666eda1` |

The image's `version.json` reports `f84d215`: the image was built before the commit
messages were tidied, which changed the commit IDs but not the code. `f84d215c` and
`d42afed8` (app) and `9388c8f` and `666eda1` (OS) have identical file trees. Seven verifiers passed on this build
(`verify`, `verify-img`, `verify-app`, `verify-imports`, `verify-crypto`,
`verify-reader`, `verify-seed-layout`).

## In this release

- Load a seed from a SeedKeeper card; choose whether to use a passphrase stored with it
- Save a seed to a card, labelled with its fingerprint and checked by reading it back
  (a BIP-39 passphrase is saved with the seed)
- SEC1210 contact reader and PN532 NFC reader, each switchable in
  Settings › Hardware › Smartcard interfaces
- Card-wait screen with an NFC connection-quality bar
- Full-keyboard, masked PIN (4–16 characters)
- Wrong-PIN countdown; a card set up on Custos wipes itself after five wrong PINs
- Install, uninstall and set up the SeedKeeper applet (v0.2-0.1, bundled and hash-checked)
- Gold UI, Custos boot logo, 320×240 display by default
- Everything else is stock SeedSigner

## Known limitations

- **Beta.** Keep a second backup of any seed you store on a card.
- Only the pi0 image is built and tested.
- Camera dice scanning was tried and removed because it did not read real dice
  reliably. Manual dice entry (stock SeedSigner) is unchanged.
- Based on SeedSigner `dev` at `1fb29563` (2026-07-22) and SeedSigner OS `main` at
  `d5a1077` (2026-07-27); later upstream changes are not merged yet.

## Licences

The image contains the SeedKeeper applet (AGPL-3.0, Satochip), unmodified. Its
corresponding source is the
[`v0.2-0.1` tag of Toporin/Seedkeeper-Applet](https://github.com/Toporin/Seedkeeper-Applet/tree/v0.2-0.1).
Custos and SeedSigner code is MIT; other packages keep their own licences.
