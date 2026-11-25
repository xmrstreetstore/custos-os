# Custos OS v0.2 (beta)

A SeedSigner build for the Raspberry Pi Zero v1.3 that loads and saves seeds on
SeedKeeper smartcards, by contact (SEC1210 HAT) or NFC (PN532). This release fixes
QR brightness, makes PIN mistakes recoverable and keeps settings across reboots.

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
| `custos.v0.2.img` (50 MB) | The image you will flash |
| `custos-v0.2-manifest.txt` | The image's fingerprint (checksum) |
| `custos-v0.2-manifest.txt.asc` | Our signature on that checksum |
| `custos-v0.2-manifest.txt.sig` | The same signature in binary form. You need only one of the two. |
| `xmrstreetstore-pubkey.asc` | Our public key. Step 4 can also fetch it for you; Sparrow needs the file. |

### Step 3. Open a terminal in that folder

- **Windows:** open **PowerShell** and type `cd $HOME\Downloads`
- **macOS / Linux:** open **Terminal** and type `cd ~/Downloads`

### Step 4. Import our signing key

Type this (the same on every system):

```
gpg --keyserver hkps://keys.openpgp.org --recv-keys E8C0F756E61138137DFF39BEF1FD97FD5D2AAA2C
```

If you downloaded `xmrstreetstore-pubkey.asc`, you can type `gpg --import xmrstreetstore-pubkey.asc` instead.
Either way it should say `public key "xmrstreetstore <info@xmrstreet.store>" imported`.
The same key is also published at [github.com/xmrstreetstore.gpg](https://github.com/xmrstreetstore.gpg),
[custos-os.com](https://custos-os.com/xmrstreetstore.asc), keyserver.ubuntu.com and
[in the repo](https://github.com/xmrstreetstore/custos-os/blob/master/keys/xmrstreetstore.asc),
so you can compare its fingerprint across sources.

### Step 5. Check the signature

```
gpg --verify custos-v0.2-manifest.txt.asc custos-v0.2-manifest.txt
```

If you downloaded `custos-v0.2-manifest.txt.sig` instead, type `gpg --verify custos-v0.2-manifest.txt.sig custos-v0.2-manifest.txt`.

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

- **Linux:** `sha256sum -c custos-v0.2-manifest.txt` must print `custos.v0.2.img: OK`
- **macOS:** `shasum -a 256 -c custos-v0.2-manifest.txt` must print `custos.v0.2.img: OK`
- **Windows (PowerShell):** this must print `True`:
  ```
  (Get-FileHash custos.v0.2.img).Hash -eq (Get-Content custos-v0.2-manifest.txt).Split(' ')[0]
  ```

> [!CAUTION]
> **Stop** if you get anything else. Delete the files and download them again.

For reference, the image's SHA256 is
`647dc565ade3d08833773a1d233f894aa18aff383537dfb963d4d85b64dcdbb4`.

### Or: check it with Sparrow

If you use [Sparrow Wallet](https://sparrowwallet.com), it can do steps 4 to 6 for you.

1. Download `custos.v0.2.img`, `custos-v0.2-manifest.txt`, `custos-v0.2-manifest.txt.asc` and `xmrstreetstore-pubkey.asc`
   into the same folder.
2. In Sparrow, open **Tools › Verify Download**.
3. Next to **Signature**, click **Browse** and pick `custos-v0.2-manifest.txt.asc`. Sparrow fills in
   the Manifest and Release File by itself.
4. Next to **Public Key**, click **Browse** and pick `xmrstreetstore-pubkey.asc`.
5. Sparrow must report a good signature from `xmrstreetstore <info@xmrstreet.store>`
   and that the release file matched the manifest hash. If it doesn't, stop.

### Step 7. Flash the microSD card

1. Open [Raspberry Pi Imager](https://www.raspberrypi.com/software/) (or
   [balenaEtcher](https://etcher.balena.io)).
2. In Raspberry Pi Imager, choose **Choose OS → Use custom** and pick `custos.v0.2.img`.
3. Choose your microSD card and write it. If it asks to apply OS customisation
   settings, choose **No**.
4. Put the card in the Raspberry Pi Zero v1.3 and power it on.

## Built from

| Repo | Tag | Commit |
|---|---|---|
| custos-seedsigner | `v0.2` | `db7e213b` |
| custos-seedsigner-os | `v0.2` | `5988bf1` |

The image's `version.json` reports `db7e213`. Verifiers passed on this build:
all seven (`verify`, `verify-img`, `verify-app`, `verify-imports`,
`verify-crypto`, `verify-reader`, `verify-seed-layout`).

## What changed since v0.1

**Fixes**
- **QR brightness works.** UP/DOWN on a QR screen (xpub export, signed transaction,
  SeedQR) now makes the QR brighter or darker. It did nothing before: the image has
  no `qrencode`, and the fallback encoder ignored the brightness. This was a stock
  SeedSigner bug too.
- **PIN mistakes no longer end on the main menu.** A PIN that is too short or too long,
  two PINs that don't match, or a wrong PIN with tries left now say what was wrong and
  offer *Try again*. Only a wiped or locked card ends the flow.
- **Settings survive a reboot.** With persistent settings on, a late SD-card mount
  used to overwrite the saved settings with the defaults.

**New**
- Saving a seed to a card that has no PIN yet offers *Set up card*, then saves
  without asking for the PIN again.

**New defaults** (only on a device without saved settings; saved settings are kept)
- Script types: **native segwit only**. Nested segwit and taproot can be turned on
  under Settings › Advanced › Script types. With one type, the script menu is skipped.
- Xpub QR format: **animated only**. Static can be turned on under
  Settings › Advanced › Xpub QR format.
- Camera rotation: **0°** (stock SeedSigner: 180°).

## Known limitations

- **Beta.** Keep a second backup of any seed you store on a card.
- Only the pi0 image is built and tested.
- Camera dice scanning stays out. Manual dice entry (stock SeedSigner) is unchanged.
- Based on SeedSigner `dev` at `1fb29563` (2026-07-22) and SeedSigner OS `main` at
  `d5a1077` (2026-07-27); later upstream changes are not merged yet.

## Licences

The image contains the SeedKeeper applet (AGPL-3.0, Satochip), unmodified. Its
corresponding source is the
[`v0.2-0.1` tag of Toporin/Seedkeeper-Applet](https://github.com/Toporin/Seedkeeper-Applet/tree/v0.2-0.1).
Custos and SeedSigner code is MIT; other packages keep their own licences.
