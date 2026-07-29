#!/bin/bash
# Read config.txt straight out of the FAT partition of the finished .img - the
# artifact that actually gets flashed, not a staging directory.
set -e
IMG=$(ls /work/os/images/*.img | head -1)
echo "image: $IMG  ($(stat -c%s "$IMG") bytes)"
echo "sha256: $(sha256sum "$IMG" | cut -d' ' -f1)"
echo

START=$(/sbin/fdisk -l -o Start "$IMG" | tail -n1)
OFFSET=$(( START * 512 ))
echo "FAT partition starts at sector $START (byte $OFFSET)"
echo
echo "=== files on the boot partition ==="
mdir -i "$IMG@@$OFFSET" :: | sed 's/^/  /'
echo
echo "=== config.txt as shipped ==="
mtype -i "$IMG@@$OFFSET" ::config.txt | sed 's/^/  /'
echo
echo "=== required settings ==="
tmp=$(mktemp)
mtype -i "$IMG@@$OFFSET" ::config.txt > "$tmp"
fail=0
for want in 'dtparam=spi=on' 'dtoverlay=disable-bt' 'dtoverlay=disable-wifi' 'dtoverlay=mmc'; do
  if grep -qxF "$want" "$tmp"; then printf "  [ok]   %s\n" "$want"; else printf "  [FAIL] %s\n" "$want"; fail=1; fi
done
echo
[ $fail -eq 0 ] && echo "IMG-VERIFY-OK" || echo "IMG-VERIFY-FAILED"
exit $fail
