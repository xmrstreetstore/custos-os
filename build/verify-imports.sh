#!/bin/bash
# Actually import the modules, using the target's own ARM python under qemu.
#
# Static "is the directory present" checks passed twice while the device still
# said "No module named 'ecdsa'" - a package can be installed and still fail to
# import because of something further down its own chain. This runs the real
# interpreter against the real rootfs, so a missing dependency is found here
# rather than on a screen after a 40-minute build and a card swap.
set -e
T=/work/os/output/target

if ! command -v qemu-arm-static >/dev/null 2>&1; then
  echo "installing qemu-user-static..."
  apt-get -qq update >/dev/null 2>&1
  apt-get -qq install -y qemu-user-static >/dev/null 2>&1 || {
    echo "  could not install qemu-user-static; skipping the live import test"
    exit 0
  }
fi

PY=$(ls "$T"/usr/bin/python3.* 2>/dev/null | grep -E 'python3\.[0-9]+$' | head -1)
[ -n "$PY" ] || PY="$T/usr/bin/python3"
echo "target interpreter: ${PY#$T}"
echo

fail=0
run_import() {
  desc="$1"; code="$2"
  if out=$(qemu-arm-static -L "$T" "$PY" -c "$code" 2>&1); then
    printf "  [ok]   %s\n" "$desc"
    [ -n "$out" ] && echo "$out" | sed 's/^/         /'
  else
    printf "  [FAIL] %s\n" "$desc"
    echo "$out" | tail -4 | sed 's/^/         /'
    fail=1
  fi
}

echo "=== the imports our screens actually perform ==="
run_import "import pysatochip.CardConnector" \
  "from pysatochip.CardConnector import CardConnector; print('CardConnector ok')"
run_import "import pysatochip.JCconstants" \
  "from pysatochip.JCconstants import SEEDKEEPER_DIC_TYPE; print(len(SEEDKEEPER_DIC_TYPE), 'secret types')"
run_import "import smartcard (pyscard)" \
  "from smartcard.System import readers; print('pyscard ok')"
run_import "import embit bip39" \
  "from embit import bip39; print(bip39.mnemonic_from_bytes(bytes(16))[:20], '...')"
run_import "import pygp (applet install)" \
  "import pygp; print('pygp ok')"

# The app must not ship the camera dice reader: it was withdrawn (app f84d215c)
# because it did not read real dice, and a stale copy must not come back.
echo
echo "=== the dice scanner is gone ==="
# PYTHONPATH names the app inside the target tree (qemu -L does not redirect it),
# and seedsigner.helpers is imported first so "absent" cannot mean "app not found".
PYTHONPATH="$T/opt/src" run_import "no dice reader in the app"   "import seedsigner.helpers, importlib.util as u; assert u.find_spec('seedsigner.helpers.dice_reader') is None; print('dice reader absent')"

echo
[ $fail -eq 0 ] && echo "IMPORT-VERIFY-OK" || echo "IMPORT-VERIFY-FAILED"
exit $fail
