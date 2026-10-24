# Custos OS v0.1 (beta)

First public release. A SeedSigner build for the Raspberry Pi Zero v1.3 that loads
and saves seeds on SeedKeeper smartcards, by contact (SEC1210 HAT) or NFC (PN532).

## Download

| File | SHA256 |
|---|---|
| `custos.pi0.img` (50 MB) | `f1993c7963f4bf5d96d7f86bc55c362cfb9acfa6b82fb38704cb9c522da8bb2b` |

Verify with `sha256sum -c SHA256SUMS`, then flash to a microSD card.

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
