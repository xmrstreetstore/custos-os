#!/bin/bash
# Verify the built rootfs actually contains the SeedKeeper stack, rather than
# trusting that the defconfig entries did what they claim.
#
#   verify.sh            check as a RELEASE image (no radios at all)
#   verify.sh dev        check as a DEV image (wifi kept for SSH, BT still off)
#
# The mode matters. A dev image legitimately ships wifi firmware, so running the
# release policy against one produces failures that are not failures - and a check
# that cries wolf is worse than no check, because the day a release image really
# does carry a radio blob, nobody will look.
MODE="${1:-release}"
T=/work/os/output/target
FW=/work/os/output/images/rpi-firmware
fail=0
echo "### verifying as: $MODE ###"

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
echo "=== boot config ==="
# Bluetooth is off in BOTH modes: it owns /dev/ttyAMA0, which the SEC1210 needs.
# Wifi is off only in release; dev keeps it deliberately, for SSH.
wants='dtparam=spi=on dtoverlay=disable-bt dtoverlay=mmc'
[ "$MODE" = release ] && wants="$wants dtoverlay=disable-wifi"
for want in $wants; do
  if grep -qF "$want" "$FW/config.txt" 2>/dev/null; then ok "$want"; else bad "$want"; fi
done
if [ "$MODE" = dev ]; then
  grep -qF 'dtoverlay=dwc2' "$FW/config.txt" 2>/dev/null \
    && ok "dtoverlay=dwc2 (USB ethernet gadget - the only way onto a Zero 1.3)" \
    || bad "dtoverlay=dwc2 missing: no way to reach a Zero 1.3"
fi

echo
echo "=== radio firmware ==="
blobs=$(find "$T/lib/firmware" -iname '*brcm*' 2>/dev/null | wc -l)
if [ "$MODE" = release ]; then
  # The single most important claim a release image makes. Fail loudly.
  if [ "$blobs" -eq 0 ]; then ok "no brcm firmware blobs (release)"
  else bad "$blobs brcm firmware blobs in a RELEASE image"; fi
else
  ok "$blobs brcm firmware blobs (expected: dev image keeps wifi)"
fi

echo
[ $fail -eq 0 ] && echo "VERIFY-OK" || echo "VERIFY-FAILED"
exit $fail
