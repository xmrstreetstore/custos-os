#!/bin/bash
# Run the Orange Kingdom's own selftest using the TARGET's ARM python and the
# TARGET's Pillow, under qemu.
#
# Why this exists, given the game is already tested on the dev box: the image ships
# `python-pillow-ep`, a custom buildroot package, not the Pillow the game has ever
# been tested against. The game leans on point(), split(), merge('LA'),
# alpha_composite(), ImageChops and paste-with-mask - all ordinary, and all
# unverified against that build. A Pillow feature missing here shows up as a black
# screen on a Pi Zero after a card swap, and no file-presence check can see it.
#
# It also proves the *shipped copy* of the game is intact and importable, which is a
# different and stronger claim than "run.py exists" - which is all
# pi0/board/post-build.sh can assert at build time.
#
# Companion to the post-build assertions rather than a replacement: those fail the
# build, this inspects what the build produced.
set -e
T=/work/os/output/target

if [ ! -f "$T/opt/kingdom/run.py" ]; then
  echo "FAIL: no game at $T/opt/kingdom - this is not a combined image."
  exit 1
fi

if ! command -v qemu-arm-static >/dev/null 2>&1; then
  echo "installing qemu-user-static..."
  apt-get -qq update >/dev/null 2>&1
  apt-get -qq install -y qemu-user-static >/dev/null 2>&1 || {
    echo "  could not install qemu-user-static; cannot run the target selftest"
    exit 1
  }
fi

PY=$(ls "$T"/usr/bin/python3.* 2>/dev/null | grep -E 'python3\.[0-9]+$' | head -1)
[ -n "$PY" ] || PY="$T/usr/bin/python3"
echo "target interpreter: ${PY#$T}"
echo

echo "=== every Pillow call the game makes, on the shipped Pillow ==="
qemu-arm-static -L "$T" "$PY" -c "
import PIL, PIL.Image as I, PIL.ImageChops as C
print('Pillow', PIL.__version__)
im = I.new('RGB', (8, 8), (255, 0, 0))
im.point(lambda v: v)                                  # LUT path in the RGB565 packer
r, g, b = im.split()
I.merge('LA', (r, g))                                  # the 2-byte packing trick
I.alpha_composite(im.convert('RGBA'), im.convert('RGBA'))
C.difference(im, im)
im.paste(im, (0, 0), im.convert('L'))
print('ok')
"

echo
echo "=== the launcher is the combined-image one ==="
grep -q kingdom "$T/start.sh" || { echo "FAIL: /start.sh does not know about the game"; exit 1; }
grep -q 42 "$T/start.sh" || { echo "FAIL: /start.sh does not handle the handoff exit code"; exit 1; }
echo "  [ok]   /start.sh starts the game and handles exit 42"

echo
echo "=== the game's own selftest, on target python ==="
cd "$T/opt/kingdom"
qemu-arm-static -L "$T" "$PY" run.py --selftest

echo
echo "GAME-VERIFY-OK"
