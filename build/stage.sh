#!/bin/bash
# Copy the working trees into the build volume.
#
# Preserves the two things that are expensive to recreate and are NOT source:
# buildroot's download cache (BR2_DL_DIR, ~700MB of upstream tarballs) and the
# buildroot submodule checkout. An earlier version wiped both on every restage,
# which quietly turned a warm rebuild back into a cold one.
set -e
git config --global --add safe.directory '*'

KEEP=/work/.keep
mkdir -p "$KEEP"

# Park the caches before the wipe.
[ -d /work/os/buildroot_dl ] && { rm -rf "$KEEP/buildroot_dl"; mv /work/os/buildroot_dl "$KEEP/"; }
[ -d /work/os/opt/buildroot/.git ] && { rm -rf "$KEEP/buildroot"; mv /work/os/opt/buildroot "$KEEP/"; }

rm -rf /work/os /work/app
mkdir -p /work/os /work/app
echo "== copying sources into the volume =="
cp -a /src/seedsigner-os/. /work/os/
cp -a /src/seedsigner/. /work/app/

# Put the caches back.
[ -d "$KEEP/buildroot_dl" ] && { rm -rf /work/os/buildroot_dl; mv "$KEEP/buildroot_dl" /work/os/; echo "restored download cache"; }
[ -d "$KEEP/buildroot" ] && { rm -rf /work/os/opt/buildroot; mv "$KEEP/buildroot" /work/os/opt/; echo "restored buildroot checkout"; }

cd /work/os
if [ ! -d opt/buildroot/.git ]; then
  echo "== initialising the buildroot submodule =="
  git submodule update --init --depth 1 opt/buildroot 2>&1 | tail -3
fi
echo "buildroot: $(du -sh opt/buildroot 2>/dev/null | cut -f1)"
echo "dl cache:  $(du -sh buildroot_dl 2>/dev/null | cut -f1 || echo 'none - will re-download')"

echo "== app fork =="
echo "branch: $(git -C /work/app rev-parse --abbrev-ref HEAD)"
echo "head:   $(git -C /work/app log --oneline -1)"
ls /work/app/javacard-cap

echo "== os fork =="
echo "branch: $(git -C /work/os rev-parse --abbrev-ref HEAD)"
echo "head:   $(git -C /work/os log --oneline -1)"
grep -E 'PYSATOCHIP|PYSCARD|PYGP|CCID_SEC1210' /work/os/opt/pi0/configs/pi0_defconfig

echo "== selftest staged =="
ls -l /work/os/opt/rootfs-overlay/usr/bin/smartcard-selftest \
      /work/os/opt/rootfs-overlay/etc/init.d/S90selftest

echo "STAGE-OK"
