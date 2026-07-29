#!/bin/bash
# Check the SeedKeeper feature actually landed in the rootfs.
#
# The app ships as .py (plus __pycache__), not stripped to .pyc as first assumed -
# an earlier version of this script tested for both and for top-level .pyc paths,
# and reported a perfectly good image as broken three times over.
T=/work/os/output/target/opt/src/seedsigner
fail=0
ok()  { printf "  [ok]   %s\n" "$1"; }
bad() { printf "  [FAIL] %s\n" "$1"; fail=1; }

echo "=== new modules present ==="
for m in helpers/seedkeeper views/seedkeeper_views gui/screens/seedkeeper_screens; do
  [ -f "$T/$m.py" ] && ok "$m.py" || bad "$m.py missing"
done

echo
echo "=== wiring survived into the shipped sources ==="
grep -q "SeedKeeperSelectView" "$T/views/seed_views.py" 2>/dev/null \
  && ok "seed_views routes to SeedKeeperSelectView" \
  || bad "seed_views lost the SeedKeeper route"
grep -q "From SeedKeeper" "$T/views/seed_views.py" 2>/dev/null \
  && ok "'From SeedKeeper' button present" \
  || bad "'From SeedKeeper' label missing"
grep -q "SmartcardMenuView" "$T/views/tools_views.py" 2>/dev/null \
  && ok "tools_views routes to SmartcardMenuView" \
  || bad "tools_views lost the Smartcard route"

echo
echo "=== they compile under the target python ==="
for m in helpers/seedkeeper views/seedkeeper_views gui/screens/seedkeeper_screens \
         views/seed_views views/tools_views; do
  if python3 -m py_compile "$T/$m.py" 2>/dev/null; then ok "$m compiles"
  else bad "$m does NOT compile"; fi
done

echo
echo "=== libraries those screens reach for ==="
SP=$(ls -d /work/os/output/target/usr/lib/python3*/site-packages 2>/dev/null | head -1)
for m in pysatochip smartcard pygp embit; do
  [ -d "$SP/$m" ] && ok "$m" || bad "$m missing"
done

echo
echo "=== pysatochip's own dependencies ==="
# Shipping pysatochip without these gets you "No module named 'ecdsa'" on the
# device, which is exactly how the first build failed: the package builds fine,
# and only breaks when something imports it. ecdsa and pyaes are needed at import
# time by CardConnector's chain; Cryptodome is used lazily by the certificate
# validator; OpenSSL is guarded by try/except and genuinely optional.
for m in ecdsa pyaes Cryptodome; do
  [ -d "$SP/$m" ] && ok "$m" || bad "$m missing - pysatochip will fail to import"
done

echo
echo "=== applets the installer offers ==="
ls /work/os/output/target/opt/javacard-cap/*.cap 2>/dev/null | sed 's|.*/|  |' \
  || bad "no .cap files"

echo
[ $fail -eq 0 ] && echo "APP-VERIFY-OK" || echo "APP-VERIFY-FAILED"
exit $fail
