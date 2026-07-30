#!/bin/bash
# Check the smartcard reader can actually be reached, not just that its
# software is installed.
#
# Written after an image shipped in which every python package imported
# cleanly and the app was wired up correctly, yet the device still failed with
# SCARD_E_NO_SERVICE. Two things no existing check looked at were wrong: the
# pi0 kernel had no PL011 driver, so /dev/ttyAMA0 could never exist, and pcscd
# killed itself at boot because libusb could not initialise on a kernel with
# no USB stack. Both are invisible to "is the package present" tests.
T=/work/os/output/target
fail=0
ok()  { printf "  [ok]   %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; fail=1; }

echo "=== the kernel can drive the reader's UART ==="
K=$(ls -d /work/os/output/build/linux-* 2>/dev/null | head -1)
if grep -q '^CONFIG_SERIAL_AMBA_PL011=y' "$K/.config" 2>/dev/null; then
  ok "CONFIG_SERIAL_AMBA_PL011=y  (/dev/ttyAMA0 will exist)"
else
  bad "PL011 driver absent - the SEC1210 can never be opened"
fi
# A console on ttyAMA0 would fight the reader for the same port, in both
# directions - but only if one is actually registered, and building the driver
# in does not register anything. Stock builds PL011_CONSOLE=y on pi2, pi02w and
# pi4; only pi0 leaves it out. Judging the image by that symbol failed the pi4
# image for something upstream ships and the reader never notices, so check the
# two places a console actually gets named instead.
CMDLINE=/work/os/output/images/rpi-firmware/cmdline.txt
grep -q '^CONFIG_SERIAL_AMBA_PL011_CONSOLE=y' "$K/.config" 2>/dev/null \
  && echo "  [note] PL011_CONSOLE is built in (stock does this) - harmless unless named below" \
  || ok "PL011 console not even built"
if grep -qE 'console=(ttyAMA|ttyS|serial)' "$CMDLINE" 2>/dev/null; then
  bad "cmdline.txt puts a console on a serial port: $(cat "$CMDLINE")"
else
  ok "cmdline.txt names no serial console: $(cat "$CMDLINE" 2>/dev/null)"
fi
# The devicetree's stdout-path is the other way in, and the one that bites when
# cmdline.txt is bare: the rpi dtbs point it at serial0. The kernel consults it
# only as a fallback though - of_console_check() returns early once
# console_set_on_cmdline is set, so any console= at all, even console=tty1,
# takes the devicetree out of the running.
if grep -q 'console=' "$CMDLINE" 2>/dev/null; then
  ok "a console= is set, so the devicetree's stdout-path is ignored"
elif grep -aq 'serial0:' /work/os/output/images/*.dtb 2>/dev/null; then
  bad "no console= in cmdline.txt, so the dtb's stdout-path will claim serial0"
else
  ok "no console anywhere"
fi
grep -q '^enable_uart=1' /work/os/output/images/rpi-firmware/config.txt 2>/dev/null \
  && ok "enable_uart=1 in config.txt" \
  || bad "enable_uart=1 missing - UART clock not guaranteed"

echo
echo "=== the daemon survives a machine with no USB ==="
if grep -q 'no USB support: continuing with serial readers only' "$T/usr/sbin/pcscd" 2>/dev/null; then
  ok "pcscd carries the no-suicide patch"
else
  bad "pcscd is unpatched - it will kill itself when libusb_init fails"
fi

echo
echo "=== reader declared where pcscd looks for it ==="
if grep -q '^DEVICENAME.*ttyAMA0:SEC1210URT' "$T/etc/reader.conf.d/sec1210" 2>/dev/null; then
  ok "reader.conf.d/sec1210 points at /dev/ttyAMA0"
else
  bad "reader.conf.d/sec1210 missing or wrong"
fi
[ -f "$T/usr/lib/pcsc/drivers/serial/libccidtwin.so" ] \
  && ok "serial CCID driver present" \
  || bad "libccidtwin.so missing"
[ -x "$T/etc/init.d/S01pcscd" ] \
  && ok "S01pcscd is executable" \
  || bad "S01pcscd missing or not executable"

echo
echo "=== run it: does pcscd stay up and serve clients? ==="
# This is the part that matters. Everything above can pass while the daemon
# still dies on contact with reality, which is exactly what happened.
if ! command -v qemu-arm-static >/dev/null 2>&1; then
  apt-get -qq update >/dev/null 2>&1
  apt-get -qq install -y qemu-user-static >/dev/null 2>&1
fi
if command -v qemu-arm-static >/dev/null 2>&1; then
  cp -f "$(command -v qemu-arm-static)" "$T/usr/bin/"
  mount --bind /dev "$T/dev" 2>/dev/null
  rm -rf "$T/run/pcscd"
  chroot "$T" /usr/bin/qemu-arm-static /usr/sbin/pcscd --foreground --debug \
    > /tmp/pcscd-verify.log 2>&1 &
  pcscd_pid=$!
  sleep 6
  # Track the pid directly rather than reaching for pgrep/pkill: this builder
  # image has neither, and an earlier version of this check reported a healthy
  # daemon as dead purely because the tool was missing.
  if kill -0 "$pcscd_pid" 2>/dev/null; then
    ok "daemon still running after libusb failed"
  else
    bad "daemon died - clients will get SCARD_E_NO_SERVICE"
  fi
  [ -S "$T/run/pcscd/pcscd.comm" ] \
    && ok "client socket /run/pcscd/pcscd.comm exists" \
    || bad "no client socket - EstablishContext will fail"
  grep -q 'Direct suicide' /tmp/pcscd-verify.log \
    && bad "pcscd took the suicide path" \
    || ok "no suicide in the log"
  # The reader itself cannot open here: a chroot has no real SEC1210. That the
  # attempt is made at all proves the config is being read.
  grep -q 'SEC1210' /tmp/pcscd-verify.log \
    && ok "pcscd tried to bring up SEC1210" \
    || bad "pcscd never looked for the SEC1210"
  kill "$pcscd_pid" 2>/dev/null
  sleep 1
  umount "$T/dev" 2>/dev/null
else
  echo "  (qemu unavailable - skipped the live daemon test)"
fi

echo
[ $fail -eq 0 ] && echo "READER-VERIFY-OK" || echo "READER-VERIFY-FAILED"
exit $fail
