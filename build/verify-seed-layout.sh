#!/bin/bash
# Write a seed the way the card stores it, then read it back - using the
# target's own python and its own embit, under qemu.
#
# This is the check with the worst failure mode behind it. Every other verifier
# guards something that breaks loudly: a missing module, a daemon that will not
# start, a config symbol left off. A wrong byte in the secret layout breaks
# nothing at all. The card accepts it, the write reports success, the screen
# says the seed is saved - and it is only ever discovered by someone trying to
# restore a wallet from a backup that cannot be read.
#
# So it exercises the real pair: build_seed_secret() lays a seed out and
# export_mnemonic() - the same function the device uses to load one - has to
# give back exactly the words and passphrase that went in. Run against the
# target rootfs rather than the host, because the entropy and the master seed
# come from embit and it is the shipped embit that has to agree.
set -e
T=/work/os/output/target

if ! command -v qemu-arm-static >/dev/null 2>&1; then
  echo "installing qemu-user-static..."
  apt-get -qq update >/dev/null 2>&1
  apt-get -qq install -y qemu-user-static >/dev/null 2>&1 || {
    echo "  could not install qemu-user-static; skipping the seed layout test"
    exit 0
  }
fi

PY=$(ls "$T"/usr/bin/python3.* 2>/dev/null | grep -E 'python3\.[0-9]+$' | head -1)
[ -n "$PY" ] || PY="$T/usr/bin/python3"
echo "target interpreter: ${PY#$T}"
echo

cat > /tmp/seed_layout_check.py <<'PYEOF'
import sys, types, hashlib

HELPER = "/opt/src/seedsigner/helpers/seedkeeper.py"
sk = types.ModuleType("sk")
exec(compile(open(HELPER).read(), HELPER, "exec"), sk.__dict__)

fails = []


def make_header(secret_type, export_rights, label, subtype=0x00):
    """pysatochip CardConnector.make_header, which the fake card must provide."""
    return bytes(2 * [0x00] + [secret_type, 0x00, export_rights] + 3 * [0x00]
                 + 4 * [0x00] + [subtype, 0x00]
                 + [len(label.encode("utf8"))] + list(label.encode("utf8"))).hex()


class FakeCard:
    def __init__(self, minor):
        self.minor = minor
        self.stored = []

    def card_get_status(self):
        return (None, None, None, {"protocol_minor_version": self.minor})

    def seedkeeper_get_status(self):
        return (None, None, None, {"free_memory": 8192})

    def make_header(self, t, r, label, subtype=0x00):
        return make_header(t, r, label, subtype)

    def seedkeeper_list_secret_headers(self):
        return self.stored

    def seedkeeper_export_secret(self, sid, sid_pubkey=None):
        for e in self.stored:
            if e["id"] == sid:
                return {"secret": e["_raw"]}
        raise Exception("no such secret")


def ok(msg):
    print("  [ok]   %s" % msg)


def bad(msg):
    print("  [FAIL] %s" % msg)
    fails.append(msg)


from embit import bip39

M12 = ("abandon " * 11) + "about"
M24 = ("abandon " * 23) + "art"


def roundtrip(minor, mnemonic, passphrase, label="test"):
    card = FakeCard(minor)
    seed_bytes = bip39.mnemonic_to_seed(mnemonic, password=passphrase)
    secret, fp, described = sk.build_seed_secret(
        card, mnemonic=mnemonic, passphrase=passphrase, label=label,
        seed_bytes=seed_bytes)
    if minor <= sk.PROTOCOL_MINOR_V1:
        stype, subtype = sk.TYPE_BIP39, 0x00
    else:
        stype, subtype = sk.TYPE_MASTERSEED, sk.SUBTYPE_MASTERSEED_BIP39
    card.stored.append({
        "id": 1, "_raw": bytes(secret["secret_list"]).hex(), "fingerprint": fp,
        "label": label, "type": stype, "subtype": subtype,
        "export_rights": sk.EXPORT_PLAINTEXT_ALLOWED,
    })
    return sk.export_mnemonic(card, 1, stype, subtype), secret, fp, described, card


print("=== a saved seed comes back word for word ===")
for minor in (1, 2):
    for mnemonic, passphrase in ((M12, ""), (M12, "trezor"),
                                 (M24, ""), (M24, "a longer one !@#")):
        got = roundtrip(minor, mnemonic, passphrase)[0]
        what = "v%d, %d words, passphrase %r" % (
            minor, len(mnemonic.split()), passphrase)
        if got == (mnemonic, passphrase):
            ok(what)
        else:
            bad("%s -> %r" % (what, got))

print()
print("=== the master seed on the card is the one this device derives ===")
_g, secret, _f, _d, _c = roundtrip(2, M12, "trezor")
payload = bytes(secret["secret_list"])
on_card = payload[1:1 + payload[0]]
if on_card == bip39.mnemonic_to_seed(M12, password="trezor"):
    ok("masterseed bytes match embit")
else:
    bad("masterseed written does not match embit")

print()
print("=== the format follows the card generation ===")
for minor, want in ((1, "BIP39 mnemonic"), (2, "Masterseed + BIP39")):
    got = roundtrip(minor, M12, "")[3]
    ok("v%d -> %s" % (minor, got)) if got == want else bad(
        "v%d -> %s, wanted %s" % (minor, got, want))

print()
print("=== and the seed is offered back by the loader ===")
for minor in (1, 2):
    card = roundtrip(minor, M12, "")[4]
    n = len(sk.list_importable(card))
    ok("v%d: list_importable offers it" % minor) if n == 1 else bad(
        "v%d: list_importable returned %d entries" % (minor, n))

print()
print("=== the fingerprint is the one the card will compute ===")
_g, secret, fp, _d, _c = roundtrip(2, M12, "")
want = hashlib.sha256(bytes(secret["secret_list"])).hexdigest()[0:8]
ok("sha256(secret)[:8]") if fp == want else bad("fingerprint %s != %s" % (fp, want))

print()
print("=== a card that lies is not believed ===")


class Lying(FakeCard):
    def seedkeeper_import_secret(self, secret_dic, sid_pubkey=None):
        return 7, "00000000"           # pysatochip only logs this mismatch

    def seedkeeper_list_secret_headers(self):
        return [{"id": 7}]


class Forgetful(FakeCard):
    def seedkeeper_import_secret(self, secret_dic, sid_pubkey=None):
        return 9, "abcdef12"

    def seedkeeper_list_secret_headers(self):
        return []                      # reports success, stored nothing


for cls, what in ((Lying, "fingerprint mismatch"), (Forgetful, "secret not listed")):
    try:
        sk.import_secret(cls(2), {"header": "00", "secret_list": [1]}, "abcdef12")
        bad("accepted a card reporting %s" % what)
    except sk.SeedKeeperError:
        ok("refused: %s" % what)

print()
if fails:
    print("SEED-LAYOUT-VERIFY-FAILED")
    sys.exit(1)
print("SEED-LAYOUT-VERIFY-OK")
PYEOF

cp /tmp/seed_layout_check.py "$T/tmp/seed_layout_check.py"
qemu-arm-static -L "$T" "$PY" "$T/tmp/seed_layout_check.py"
rc=$?
rm -f "$T/tmp/seed_layout_check.py"
exit $rc
