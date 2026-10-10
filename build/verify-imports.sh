#!/bin/bash
# Actually import the modules, using the target's own ARM python under qemu.
#
# Static "is the directory present" checks passed twice while the device still
# said "No module named 'ecdsa'" - a package can be installed and still fail to
# import because of something further down its own chain. This runs the real
# interpreter against the real rootfs, so a missing dependency is found here
# rather than on a screen after a 40-minute build and a card swap.
set -e
T=/work/os/output/target

if ! command -v qemu-arm-static >/dev/null 2>&1; then
  echo "installing qemu-user-static..."
  apt-get -qq update >/dev/null 2>&1
  apt-get -qq install -y qemu-user-static >/dev/null 2>&1 || {
    echo "  could not install qemu-user-static; skipping the live import test"
    exit 0
  }
fi

PY=$(ls "$T"/usr/bin/python3.* 2>/dev/null | grep -E 'python3\.[0-9]+$' | head -1)
[ -n "$PY" ] || PY="$T/usr/bin/python3"
echo "target interpreter: ${PY#$T}"
echo

fail=0
run_import() {
  desc="$1"; code="$2"
  if out=$(qemu-arm-static -L "$T" "$PY" -c "$code" 2>&1); then
    printf "  [ok]   %s\n" "$desc"
    [ -n "$out" ] && echo "$out" | sed 's/^/         /'
  else
    printf "  [FAIL] %s\n" "$desc"
    echo "$out" | tail -4 | sed 's/^/         /'
    fail=1
  fi
}

echo "=== the imports our screens actually perform ==="
run_import "import pysatochip.CardConnector" \
  "from pysatochip.CardConnector import CardConnector; print('CardConnector ok')"
run_import "import pysatochip.JCconstants" \
  "from pysatochip.JCconstants import SEEDKEEPER_DIC_TYPE; print(len(SEEDKEEPER_DIC_TYPE), 'secret types')"
run_import "import smartcard (pyscard)" \
  "from smartcard.System import readers; print('pyscard ok')"
run_import "import embit bip39" \
  "from embit import bip39; print(bip39.mnemonic_from_bytes(bytes(16))[:20], '...')"
run_import "import pygp (applet install)" \
  "import pygp; print('pygp ok')"

# The dice scanner is numpy + Pillow arithmetic, and the target is 32-bit with
# an older numpy than any desktop: np.bincount there refuses int64 indices,
# which no test on a PC can show. So draw 40 dice with the target's Pillow and
# read them back with the target's numpy, from the app as installed.
echo
echo "=== the dice scanner on the target's numpy and Pillow ==="
read -r -d '' DICE_CHECK <<'PY' || true
import random
from PIL import Image, ImageDraw
from seedsigner.helpers.dice_reader import read_dice
P = {1: [(2, 2)], 2: [(1, 1), (3, 3)], 3: [(1, 1), (2, 2), (3, 3)],
     4: [(1, 1), (3, 1), (1, 3), (3, 3)], 5: [(1, 1), (3, 1), (2, 2), (1, 3), (3, 3)],
     6: [(1, 1), (3, 1), (1, 2), (3, 2), (1, 3), (3, 3)]}
rng = random.Random(1)
vals = [rng.randint(1, 6) for _ in range(40)]
s = 80
img = Image.new("RGB", (10 * s + 80, 4 * s + 80), (60, 45, 30))
d = ImageDraw.Draw(img)
for i, v in enumerate(vals):
    x, y = 40 + (i % 10) * s, 40 + (i // 10) * s
    d.rounded_rectangle((x + 2, y + 2, x + s - 2, y + s - 2), 12, fill=(235, 235, 230))
    for px, py in P[v]:
        cx, cy = x + px * s / 4, y + py * s / 4
        d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=(20, 20, 20))
r = read_dice(img)
assert r.values == vals, (r.values, vals)
print("read", len(r.values), "dice correctly")
PY
PYTHONPATH=/opt/src run_import "read a photo of dice" "$DICE_CHECK"

echo
[ $fail -eq 0 ] && echo "IMPORT-VERIFY-OK" || echo "IMPORT-VERIFY-FAILED"
exit $fail
