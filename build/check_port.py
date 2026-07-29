"""Static checks + a real test of the secret decoding, before spending 40 minutes."""
import ast
import os
import sys

SRC = "/r/src"
fail = 0


def ok(m):
    print(f"  [ok]   {m}")


def bad(m):
    global fail
    fail = 1
    print(f"  [FAIL] {m}")


print("=== syntax of everything we touched ===")
for rel in ("seedsigner/views/seedkeeper_views.py",
            "seedsigner/helpers/seedkeeper.py",
            "seedsigner/gui/screens/seedkeeper_screens.py",
            "seedsigner/views/seed_views.py",
            "seedsigner/views/tools_views.py"):
    path = os.path.join(SRC, rel)
    try:
        ast.parse(open(path, encoding="utf-8").read())
        ok(rel)
    except SyntaxError as exc:
        bad(f"{rel}: {exc}")

print("\n=== names imported from stock modules really exist ===")
def has(rel, name):
    tree = ast.parse(open(os.path.join(SRC, rel), encoding="utf-8").read())
    for n in ast.walk(tree):
        if isinstance(n, (ast.ClassDef, ast.FunctionDef)) and n.name == name:
            return True
        if isinstance(n, ast.Assign):
            for t in n.targets:
                if isinstance(t, ast.Name) and t.id == name:
                    return True
    return False

for rel, name in (
    ("seedsigner/gui/screens/screen.py", "KeyboardScreen"),
    ("seedsigner/gui/screens/screen.py", "ButtonListScreen"),
    ("seedsigner/gui/screens/screen.py", "WarningScreen"),
    ("seedsigner/gui/screens/screen.py", "LoadingScreenThread"),
    ("seedsigner/gui/screens/screen.py", "ButtonOption"),
    ("seedsigner/views/view.py", "View"),
    ("seedsigner/views/view.py", "Destination"),
    ("seedsigner/views/view.py", "BackStackView"),
    ("seedsigner/views/view.py", "MainMenuView"),
    ("seedsigner/views/seed_views.py", "SeedFinalizeView"),
    ("seedsigner/models/seed.py", "Seed"),
):
    (ok if has(rel, name) else bad)(f"{name} in {os.path.basename(rel)}")

print("\n=== every icon constant our new code references really exists ===")
# Derived from the source rather than hardcoded: the first attempt used
# FontAwesomeIconConstants.LOCK, which only exists in the fork, and a hardcoded
# check would not have noticed the replacement was also wrong.
import re
comp = open(os.path.join(SRC, "seedsigner/gui/components.py"), encoding="utf-8").read()
referenced = set()
for rel in ("seedsigner/views/seedkeeper_views.py",
            "seedsigner/views/seed_views.py",
            "seedsigner/views/tools_views.py"):
    body = open(os.path.join(SRC, rel), encoding="utf-8").read()
    referenced |= set(re.findall(r"(?:FontAwesome|SeedSigner)IconConstants\.([A-Z_0-9]+)", body))
for name in sorted(referenced):
    (ok if re.search(rf"^\s+{name}\s*=", comp, re.M) else bad)(f"icon {name}")

print("\n=== wiring ===")
sv = open(os.path.join(SRC, "seedsigner/views/seed_views.py"), encoding="utf-8").read()
tv = open(os.path.join(SRC, "seedsigner/views/tools_views.py"), encoding="utf-8").read()
(ok if "SeedKeeperSelectView" in sv else bad)("LoadSeedView routes to SeedKeeperSelectView")
(ok if "self.SEEDKEEPER" in sv else bad)("LoadSeedView offers the SeedKeeper button")
(ok if "SmartcardMenuView" in tv else bad)("ToolsMenuView routes to SmartcardMenuView")

print("\n=== secret decoding, against synthetic card payloads ===")
sys.path.insert(0, SRC)
# Stub the seedsigner package chain so helpers/seedkeeper.py imports standalone.
import types
for mod in ("seedsigner", "seedsigner.helpers"):
    sys.modules.setdefault(mod, types.ModuleType(mod))
spec_path = os.path.join(SRC, "seedsigner/helpers/seedkeeper.py")
ns = {}
exec(compile(open(spec_path, encoding="utf-8").read(), spec_path, "exec"), ns)

class FakeCard:
    def __init__(self, raw):
        self.raw = raw
    def seedkeeper_export_secret(self, sid, pubkey=None):
        return {"secret": self.raw.hex()}

MNEMONIC = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

# BIP39 layout: [len][mnemonic][len][passphrase]
m = MNEMONIC.encode()
p = b"hunter2"
raw = bytes([len(m)]) + m + bytes([len(p)]) + p
got_m, got_p = ns["export_mnemonic"](FakeCard(raw), 1, ns["TYPE_BIP39"], 0)
(ok if got_m == MNEMONIC else bad)(f"BIP39 mnemonic decoded ({got_m[:24]}...)")
(ok if got_p == "hunter2" else bad)(f"BIP39 passphrase decoded ({got_p!r})")

# BIP39 with no passphrase
raw = bytes([len(m)]) + m
got_m, got_p = ns["export_mnemonic"](FakeCard(raw), 1, ns["TYPE_BIP39"], 0)
(ok if got_m == MNEMONIC and got_p == "" else bad)("BIP39 with no passphrase")

# Masterseed v2: [len][masterseed][wordlist][len][entropy][len][passphrase]
entropy = bytes(16)                       # all-zero entropy -> the abandon... phrase
seed = bytes(64)
raw = (bytes([len(seed)]) + seed + bytes([0x00]) +
       bytes([len(entropy)]) + entropy + bytes([0]))
try:
    got_m, got_p = ns["export_mnemonic"](FakeCard(raw), 1, ns["TYPE_MASTERSEED"], 0x01)
    (ok if got_m == MNEMONIC else bad)(f"masterseed v2 rebuilt mnemonic ({got_m[:24]}...)")
except Exception as exc:
    bad(f"masterseed v2: {type(exc).__name__}: {exc}")

# Non-english wordlist must refuse rather than return wrong words.
raw_ja = (bytes([len(seed)]) + seed + bytes([0x01]) +
          bytes([len(entropy)]) + entropy + bytes([0]))
try:
    ns["export_mnemonic"](FakeCard(raw_ja), 1, ns["TYPE_MASTERSEED"], 0x01)
    bad("non-english wordlist was silently accepted")
except ns["SeedKeeperError"]:
    ok("non-english wordlist refused instead of returning wrong words")

print("\n" + ("PORT-CHECK-FAILED" if fail else "PORT-CHECK-OK"))
sys.exit(fail)
