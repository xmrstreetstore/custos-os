#!/bin/bash
# Read config.txt straight out of the FAT partition of the finished .img - the
# artifact that actually gets flashed, not a staging directory.
set -e
# Optional arg: literal substring of the image filename -
#   pi0-dev    the dev image
#   pi0.img    the release image ('.img' is what excludes pi0-dev)
# Refuse to guess when it matches more than one; picking the first silently
# verified the wrong image once already.
matches=$(ls /work/os/images/*.img 2>/dev/null | grep -F -- "${1:-.img}" || true)
count=$(printf '%s' "$matches" | grep -c . || true)
[ "$count" -ge 1 ] || { echo "no image matching '${1:-}'"; exit 1; }
[ "$count" -eq 1 ] || { echo "'${1:-}' matched $count images, be more specific:";
                        printf '%s\n' "$matches" | sed 's/^/  /'; exit 1; }
IMG="$matches"
echo "image: $IMG  ($(stat -c%s "$IMG") bytes)"
echo "sha256: $(sha256sum "$IMG" | cut -d' ' -f1)"
echo

echo "=== partition table ==="
/sbin/fdisk -l "$IMG" | sed -n '/^Device/,$p' | sed 's/^/  /'
echo

# The FIRST partition is the FAT boot partition. Dev images have a second (ext4
# data) partition, so taking the last one lands on ext4 and mtools reports
# "non DOS media".
START=$(/sbin/fdisk -l -o Start "$IMG" | grep -E '^\s*[0-9]+' | head -n1 | tr -d ' ')
OFFSET=$(( START * 512 ))
echo "FAT boot partition starts at sector $START (byte $OFFSET)"
echo
echo "=== files on the boot partition ==="
mdir -i "$IMG@@$OFFSET" :: | sed 's/^/  /'
echo
echo "=== config.txt as shipped ==="
mtype -i "$IMG@@$OFFSET" ::config.txt | sed 's/^/  /'
echo
# Policy is inferred from the filename rather than passed in, so it cannot be
# invoked with the wrong one. Dev images legitimately keep wifi for SSH; release
# images must not have it. Bluetooth is off in both - it owns /dev/ttyAMA0.
case "$IMG" in *-dev.img) MODE=dev ;; *) MODE=release ;; esac
echo "=== required settings (policy: $MODE) ==="
tmp=$(mktemp)
mtype -i "$IMG@@$OFFSET" ::config.txt > "$tmp"
fail=0
wants='dtparam=spi=on dtoverlay=disable-bt dtoverlay=mmc'
if [ "$MODE" = release ]; then
  wants="$wants dtoverlay=disable-wifi"
fi
for want in $wants; do
  if grep -qxF "$want" "$tmp"; then printf "  [ok]   %s\n" "$want"; else printf "  [FAIL] %s\n" "$want"; fail=1; fi
done

# The USB gadget overlay, in whichever form the board uses. pi0-dev pins
# dr_mode=peripheral because the gadget is its only way in; pi4-dev leaves dwc2
# dual-role so a keyboard on an OTG adapter still works, and reaches the shell
# over its own ethernet instead. Demanding the pi0 spelling failed a pi4 image
# that was configured exactly as intended.
if [ "$MODE" = dev ]; then
  if grep -qE '^dtoverlay=dwc2(,|$)' "$tmp"; then
    printf "  [ok]   %s\n" "$(grep -E '^dtoverlay=dwc2(,|$)' "$tmp" | head -1)"
  else
    printf "  [FAIL] %s\n" "no dtoverlay=dwc2"; fail=1
  fi
fi
if [ "$MODE" = dev ] && grep -qxF 'dtoverlay=disable-wifi' "$tmp"; then
  printf "  [FAIL] %s\n" "dev image disables wifi - SSH over wifi will not work"; fail=1
fi
echo
[ $fail -eq 0 ] && echo "IMG-VERIFY-OK" || echo "IMG-VERIFY-FAILED"
exit $fail
