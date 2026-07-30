#!/bin/bash
# Build the pi4 *dev* image: same SeedKeeper stack, but with a shell on it.
#
# This exists to debug the reader. The release images have no console, no
# network and no spare serial port, so two builds in a row could only report
# one screen of error text. The dev image keeps dropbear and wired ethernet,
# which is the one link that still works with the radios off and the SEC1210
# holding the only UART.
#
# Not a shipping artifact: it has a root password, an SSH daemon and a
# writable data partition. Use it to find out what the hardware is doing, then
# go back to the pi0 release image.
set -o pipefail
export FORCE_UNSAFE_CONFIGURE=1

cd /work/os/opt || exit 1

echo "=== pi4-dev build starting $(date -u +%H:%M:%S) ==="
echo "app:  $(git -C /work/app log --oneline -1)"
echo "os:   $(git -C /work/os log --oneline -1)"
echo

./build.sh --pi4 --dev \
    --app-repo=/work/app \
    --app-branch=seedkeeper-support 2>&1

status=$?
echo
echo "=== build.sh exited $status at $(date -u +%H:%M:%S) ==="
ls -l /work/os/images/ 2>/dev/null || echo "(no images dir)"
exit $status
