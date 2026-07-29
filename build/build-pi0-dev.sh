#!/bin/bash
# Build the pi0 DEVELOPMENT image.
#
# Same sources as build-pi0.sh, different board target. The dev image is how you
# get a shell on a Pi Zero 1.3, which has no wifi at all: dtoverlay=dwc2 exposes
# the USB port as an ethernet gadget, so plugging it into a computer gives you
# `ssh root@10.55.0.1` with no host configuration.
#
# It also keeps wifi enabled on boards that have it - stock intends that for dev -
# but disables Bluetooth, because BT owns /dev/ttyAMA0 and the SEC1210 needs it.
#
# NOT for real funds. The motd says so, and it means it.
set -o pipefail
export FORCE_UNSAFE_CONFIGURE=1

cd /work/os/opt || exit 1

echo "=== dev build starting $(date -u +%H:%M:%S) ==="
echo "app:  $(git -C /work/app log --oneline -1)"
echo "os:   $(git -C /work/os log --oneline -1)"
echo "dl cache: $(du -sh /work/os/buildroot_dl 2>/dev/null | cut -f1 || echo none)"
echo

./build.sh --pi0 --dev \
    --app-repo=/work/app \
    --app-branch=seedkeeper-support 2>&1

status=$?
echo
echo "=== build.sh exited $status at $(date -u +%H:%M:%S) ==="
ls -l /work/os/images/ 2>/dev/null
exit $status
