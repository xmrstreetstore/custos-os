#!/bin/bash
# Build the pi0 image (Raspberry Pi Zero 1.3 / Zero W) from our forks.
#
# --app-repo takes a path, so we point it at the local fork in the volume rather
# than at GitHub. That keeps the bundled javacard-cap/ and avoids --skip-repo,
# which would leave translations uncompiled and version.json unwritten.
set -o pipefail
export FORCE_UNSAFE_CONFIGURE=1

cd /work/os/opt || exit 1

echo "=== build starting $(date -u +%H:%M:%S) ==="
echo "app:  $(git -C /work/app log --oneline -1)"
echo "os:   $(git -C /work/os log --oneline -1)"
echo

# These flags only parse in --flag=value form; the help text shows them without
# the '=' and the parser rejects that outright.
./build.sh --pi0 \
    --app-repo=/work/app \
    --app-branch=seedkeeper-support 2>&1

status=$?
echo
echo "=== build.sh exited $status at $(date -u +%H:%M:%S) ==="
ls -l /work/os/images/ 2>/dev/null || echo "(no images dir)"
exit $status
