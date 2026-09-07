#!/bin/bash
# Build a soname -> package map by looking inside the published archives.
#
# provmap.json covers pkg-config names, headers and binaries but not sonames,
# and `Depends: auto` emits sonames — so nothing could turn "libxml2.so.16"
# back into "libxml2". This closes that gap. G2's capability graph needs the
# same mapping, so it is a script rather than a one-off.
#
# Reads the repository; writes only to the output file given.
set -euo pipefail
POOL="${1:-/var/www/hud-unstable/pool/main}"
OUT="${2:-/var/hud-build/sonamemap.json}"

[ -d "$POOL" ] || { echo "no pool at $POOL" >&2; exit 2; }

python3 - "$POOL" "$OUT" <<'PY'
import json, os, re, sys, tarfile
pool, out = sys.argv[1], sys.argv[2]
m = {}
for root, _, files in os.walk(pool):
    for f in files:
        if not f.endswith(".hud"):
            continue
        pkg = f.rsplit("-", 2)[0]
        try:
            with tarfile.open(os.path.join(root, f)) as t:
                names = [x.name for x in t.getmembers()]
        except Exception as e:
            print(f"skip {f}: {e}", file=sys.stderr)
            continue
        for n in names:
            # a real versioned soname under a library directory
            mt = re.search(r"/lib(?:64)?/(lib[^/]+\.so\.[0-9]+)$", n)
            if mt and "site-packages" not in n:
                m.setdefault(mt.group(1), pkg)
json.dump(dict(sorted(m.items())), open(out, "w"), indent=1)
print(f"{len(m)} sonames from {pool} -> {out}")
PY
