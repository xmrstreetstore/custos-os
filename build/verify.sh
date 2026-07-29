#!/bin/bash
# Verify the built rootfs actually contains the SeedKeeper stack, rather than
# trusting that the defconfig entries did what they claim.
T=/work/os/output/target
FW=/work/os/output/images/rpi-firmware
fail=0

ok()  { printf "  [ok]   %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; fail=1; }

check_path() { if [ -e "$1" ]; then ok "$2"; else bad "$2  (missing: $1)"; fi; }

echo "=== python modules in the rootfs ==="
SP=$(ls -d $T/usr/lib/python*/site-packages 2>/dev/null | head -1)
echo "  site-packages: ${SP#$T}"
for m in pysatochip smartcard pygp; do
  if [ -e "$SP/$m" ] || ls "$SP" 2>/dev/null | grep -qi "^$m"; then
    ok "python module: $m"
  else
    bad "python module: $m"
  fi
done

echo
echo "=== pcsc / ccid ==="
check_path "$T/usr/lib/pcsc/drivers/serial/libccidtwin.so" "serial CCID driver (libccidtwin.so)"
check_path "$T/usr/sbin/pcscd" "pcscd binary"
[ -e "$T/usr/bin/pcscd" ] && ok "pcscd binary (usr/bin)"
check_path "$T/etc/reader.conf.d/sec1210" "SEC1210 reader config"
check_path "$T/etc/init.d/S01pcscd" "pcscd init script"
if grep -q 'ttyAMA0' "$T/etc/reader.conf.d/sec1210" 2>/dev/null; then
  ok "reader points at /dev/ttyAMA0"
  grep -E 'DEVICENAME|LIBPATH' "$T/etc/reader.conf.d/sec1210" | sed 's/^/         /'
else
  bad "reader config does not mention ttyAMA0"
fi

echo
echo "=== bundled applets ==="
check_path "$T/opt/javacard-cap" "/opt/javacard-cap exists"
if [ -d "$T/opt/javacard-cap" ]; then
  ls -1 "$T/opt/javacard-cap" | sed 's/^/         /'
  (cd "$T/opt/javacard-cap" && sha256sum -c javacard-cap.sha256 2>&1 | sed 's/^/         /')
fi

echo
echo "=== the app itself ==="
check_path "$T/opt/src/seedsigner/controller.py" "seedsigner app present"
check_path "$T/opt/src/seedsigner/version.json" "version.json (missing one bricks the splash)"
[ -f "$T/opt/src/seedsigner/version.json" ] && sed 's/^/         /' "$T/opt/src/seedsigner/version.json"

echo
echo "=== boot config in the image ==="
for want in 'dtparam=spi=on' 'dtoverlay=disable-bt' 'dtoverlay=disable-wifi' 'dtoverlay=mmc'; do
  if grep -qF "$want" "$FW/config.txt" 2>/dev/null; then ok "$want"; else bad "$want"; fi
done

echo
echo "=== radios must be absent from the rootfs ==="
blobs=$(find "$T/lib/firmware" -iname '*brcm*' 2>/dev/null | wc -l)
if [ "$blobs" -eq 0 ]; then ok "no brcm wifi/bt firmware blobs"; else bad "$blobs brcm firmware blobs present"; fi

echo
[ $fail -eq 0 ] && echo "VERIFY-OK" || echo "VERIFY-FAILED"
exit $fail
