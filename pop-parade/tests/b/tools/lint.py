#!/usr/bin/env python3
"""Static checks for B-owned code (run by check.sh).

1. Every Strings key used as a literal (S.t("key") / Strings.t("key")) exists in Strings.luau.
2. No invented Roblox asset IDs anywhere in B's source/content ("rbxassetid://<digits>").
3. Production code (src/) never references the test-only folder except Paths.previewMock.
4. No "100x earnings" style claims in player-facing strings.
5. Shared content has no prices/odds/product IDs/secret coordinates.
"""
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
errors = []

def files(rel, exts=(".luau",)):
    base = os.path.join(ROOT, rel)
    for d, _, fs in os.walk(base):
        for f in fs:
            if f.endswith(exts):
                yield os.path.join(d, f)

strings_src = open(os.path.join(ROOT, "src/shared/content/Strings.luau"), encoding="utf-8").read()
keys = set(re.findall(r'\["([^"]+)"\]\s*=', strings_src))

used = {}
for path in list(files("src")) + list(files("tests/b/preview")):
    src = open(path, encoding="utf-8").read()
    for m in re.finditer(r'\b(?:S|Strings|self\.S|ctx\.S|Content\.Strings|self\.ctx\.S)\s*[.:]\s*t\(\s*"([^"]+)"', src):
        used.setdefault(m.group(1), os.path.relpath(path, ROOT))
# keys ending in '.' are dynamic prefixes ("menu." .. name); their full sets are checked in Strings.spec
missing = sorted(k for k in used if k not in keys and not k.endswith('.'))
for k in missing:
    errors.append("missing string key '%s' (used in %s)" % (k, used[k]))

# keys referenced via nameKey/displayKey/textKey/descKey fields in content
for path in files("src/shared/content"):
    src = open(path, encoding="utf-8").read()
    for m in re.finditer(r'(?:nameKey|displayKey|textKey|descKey|acquisitionHint)\s*=\s*"([^"]+)"', src):
        if m.group(1) not in keys:
            errors.append("content key '%s' missing from Strings (%s)" % (m.group(1), os.path.relpath(path, ROOT)))

for path in list(files("src")) + list(files("tests/b")) + list(files("assets", (".luau", ".json", ".md"))):
    src = open(path, encoding="utf-8").read()
    if re.search(r'rbxassetid://\d+', src):
        errors.append("hardcoded asset id in %s (assets must come from ASSET_MANIFEST with an owner/licence)" % os.path.relpath(path, ROOT))

for path in files("src"):
    rel = os.path.relpath(path, ROOT)
    src = open(path, encoding="utf-8").read()
    code = "\n".join(l.split("--", 1)[0] for l in src.splitlines())
    if "PopParadeTestB" in code and rel != os.path.join("src", "client", "Paths.luau"):
        errors.append("production file references test-only PopParadeTestB: " + rel)
    if re.search(r'require\([^)]*tests', src):
        errors.append("production file requires tests: " + rel)

for k, v in re.findall(r'\["([^"]+)"\]\s*=\s*"([^"]*)"', strings_src):
    if re.search(r'100\s*[x×]\s*(earn|coin|income|reward)', v, re.I):
        errors.append("misleading 100x earnings claim in string " + k)

for path in files("src/shared/content"):
    src = open(path, encoding="utf-8").read()
    rel = os.path.relpath(path, ROOT)
    for bad in ("productId", "priceRobux", "probability", "PriceInRobux"):
        if bad in src:
            errors.append("shared content must not contain %s (%s)" % (bad, rel))
    if "SecretsLayout" in src or "secret.rubber.waterfall" in src and "Strings" not in rel:
        errors.append("secret data leaked into shared content: " + rel)

print("lint: %d string keys used, %d defined" % (len(used), len(keys)))
if errors:
    for e in errors:
        print("LINT ERROR:", e)
    sys.exit(1)
print("lint: ok")
