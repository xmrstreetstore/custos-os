#!/bin/bash
# Check the crypto primitives against published test vectors, on the target.
#
# pygp's crypto comes from our own pygp/_crypto_backend.py rather than from
# upstream cryptography, so nobody else's test suite is watching it. A wrong
# primitive here would not crash: it would compute a valid-looking wrong MAC and
# the card would simply refuse to authenticate, which looks exactly like a wiring
# or key problem and would be debugged in the wrong place for hours.
#
# So this pins the primitives to the standards that define them, run through the
# target's own ARM interpreter under qemu - the same code path the device uses.
set -e
T=/work/os/output/target

if ! command -v qemu-arm-static >/dev/null 2>&1; then
  echo "installing qemu-user-static..."
  apt-get -qq update >/dev/null 2>&1
  apt-get -qq install -y qemu-user-static >/dev/null 2>&1 || {
    echo "  could not install qemu-user-static; skipping the vector test"
    exit 0
  }
fi

PY=$(ls "$T"/usr/bin/python3.* 2>/dev/null | grep -E 'python3\.[0-9]+$' | head -1)
[ -n "$PY" ] || PY="$T/usr/bin/python3"
echo "target interpreter: ${PY#$T}"
echo

cat > "$T/tmp/verify-crypto.py" <<'PYEOF'
from pygp import crypto

fails = []


def check(label, got, want):
    got, want = got.upper(), want.upper()
    if got == want:
        print("  [ok]   %s" % label)
    else:
        print("  [FAIL] %s" % label)
        print("         got  %s" % got)
        print("         want %s" % want)
        fails.append(label)


print("=== DES, FIPS 81 ===")
check("DES_ECB", crypto.DES_ECB("4E6F772069732074", "0123456789ABCDEF"),
      "3FA40E8A984D4815")
check("DES_INV_ECB round-trip",
      crypto.DES_INV_ECB("3FA40E8A984D4815", "0123456789ABCDEF"),
      "4E6F772069732074")

print("=== 3DES ===")
# A 3DES key whose three parts are equal is single DES. pygp reaches this path
# through DES_ECB and through MAC3's 8-byte key, and pycryptodomex refuses such
# a key outright, so the backend has to route it to DES instead.
check("K1=K2=K3 collapses to single DES",
      crypto.DES3_ECB("4E6F772069732074", "0123456789ABCDEF" * 3),
      "3FA40E8A984D4815")
k1, k2, p = "0123456789ABCDEF", "23456789ABCDEF01", "4E6F772069732074"
ede = crypto.DES_ECB(crypto.DES_INV_ECB(crypto.DES_ECB(p, k1), k2), k1)
check("2-key 3DES == E_K1(D_K2(E_K1(P)))", crypto.DES3_ECB(p, k1 + k2), ede)

print("=== AES, FIPS 197 C.1 ===")
check("AES_ECB", crypto.AES_ECB("00112233445566778899AABBCCDDEEFF",
                                "000102030405060708090A0B0C0D0E0F"),
      "69C4E0D86A7B0430D8CDB78070B4C55A")
check("AES_INV_ECB round-trip",
      crypto.AES_INV_ECB("69C4E0D86A7B0430D8CDB78070B4C55A",
                         "000102030405060708090A0B0C0D0E0F"),
      "00112233445566778899AABBCCDDEEFF")

print("=== AES-CMAC, RFC 4493 ===")
ck = "2B7E151628AED2A6ABF7158809CF4F3C"
check("CMAC of empty message", crypto.AES_CMAC("", ck),
      "BB1D6929E95937287FA37D129B756746")
check("CMAC of one block", crypto.AES_CMAC("6BC1BEE22E409F96E93D7E117393172A", ck),
      "070A16B46B4D4144F79BDD9DD04A287C")

print("=== hashes of \"abc\" ===")
abc = "616263"
check("SHA1", crypto.SHA1(abc), "A9993E364706816ABA3E25717850C26C9CD0D89D")
check("SHA256", crypto.SHA256(abc),
      "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD")
check("SHA384", crypto.SHA384(abc),
      "CB00753F45A35E8BB5A03D699AC65007272C32AB0EDED1631A8B605A43FF5BED"
      "8086072BA1E7CC2358BAECA134C825A7")
check("SHA512", crypto.SHA512(abc),
      "DDAF35A193617ABACC417349AE20413112E6FA4E89A97EA20A9EEEE64B55D39A"
      "2192992A274FC1A836BA3C23A3FEEBBD454D4423643CE80E2A9AC94FA54CA49F")

print("=== HMAC-SHA1, RFC 2202 case 1 ===")
check("HMAC", crypto.HMAC("4869205468657265", "0B" * 20, "SHA1"),
      "B617318655057264E28BC0B6FB378C8EF146BE00")

print("=== CBC chains, rather than repeating ECB ===")
iv = "0000000000000000"
two = "4E6F772069732074" + "68652074696D6520"
b1 = crypto.DES3_ECB("4E6F772069732074", k1 + k2)
xored = "%016X" % (int(b1, 16) ^ int("68652074696D6520", 16))
check("DES3_CBC == manual chain", crypto.DES3_CBC(two, k1 + k2, iv),
      b1 + crypto.DES3_ECB(xored, k1 + k2))
check("DES3_INV_CBC round-trip",
      crypto.DES3_INV_CBC(crypto.DES3_CBC(two, k1 + k2, iv), k1 + k2, iv), two)

print("=== the SCP02 MAC path, which uses the expanded 8-byte keys ===")
mac = crypto.MAC3("0102030405060708", "0123456789ABCDEF23456789ABCDEF01")
check("MAC3 returns 8 bytes", str(len(mac)), "16")
mac33 = crypto.MAC33("0102030405060708", "0123456789ABCDEF23456789ABCDEF01")
check("MAC33 returns 8 bytes", str(len(mac33)), "16")

print("=== the asymmetric helpers must not quietly return nonsense ===")
try:
    crypto.generate_RSA_keys(65537, 1024)
    print("  [FAIL] RSA key generation appeared to succeed")
    fails.append("RSA should be unusable")
except Exception as exc:
    print("  [ok]   RSA is unusable (%s)" % type(exc).__name__)

print()
if fails:
    print("CRYPTO-VERIFY-FAILED: " + ", ".join(fails))
    raise SystemExit(1)
print("CRYPTO-VERIFY-OK")
PYEOF

set +e
# The script path is the host one on purpose: -L only tells qemu where the
# target's dynamic linker and libraries live, it does not chroot. The target
# python still derives its own sys.prefix from $PY, so it imports out of the
# rootfs's site-packages rather than the builder's.
qemu-arm-static -L "$T" "$PY" "$T/tmp/verify-crypto.py"
rc=$?
set -e
rm -f "$T/tmp/verify-crypto.py"
exit $rc
