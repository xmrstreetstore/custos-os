#!/bin/bash
set -e
git config --global --add safe.directory '*'

rm -rf /work/os /work/app
mkdir -p /work/os /work/app
echo "== copying sources into the volume =="
cp -a /src/seedsigner-os/. /work/os/
cp -a /src/seedsigner/. /work/app/

cd /work/os
echo "== initialising the buildroot submodule =="
git submodule update --init --depth 1 opt/buildroot 2>&1 | tail -3
echo "buildroot: $(ls opt/buildroot | wc -l) entries, $(du -sh opt/buildroot | cut -f1)"

echo "== app fork =="
echo "branch: $(git -C /work/app rev-parse --abbrev-ref HEAD)"
echo "head:   $(git -C /work/app log --oneline -1)"
ls /work/app/javacard-cap

echo "== os fork =="
echo "branch: $(git -C /work/os rev-parse --abbrev-ref HEAD)"
echo "head:   $(git -C /work/os log --oneline -1)"
grep -c . /work/os/opt/pi0/configs/pi0_defconfig | xargs echo "pi0 defconfig lines:"
grep -E 'PYSATOCHIP|PYSCARD|PYGP|CCID_SEC1210' /work/os/opt/pi0/configs/pi0_defconfig

echo "STAGE-OK"
