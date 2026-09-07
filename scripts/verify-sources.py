#!/usr/bin/env python3
"""
Check every definition's Source-SHA256 against the cached tarball.

hud-build verifies this at build time and aborts on a mismatch, so anything
wrong here is a G1 failure waiting to happen — and it can be found in a minute
instead of in the middle of a 245-package run. It also reports which sources are
not cached at all, since G1 is supposed to need no network.
"""
import hashlib, os, re, sys

H = "/root/github-repo/huddefs/huddefs"
CACHE = "/var/hud-build/cache"


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


ok = miss = bad = nohash = 0
problems = []
for p in sorted(os.listdir(H)):
    f = os.path.join(H, p, f"{p}.huddef")
    if not os.path.exists(f):
        continue
    t = open(f, errors="replace").read()
    m = re.search(r"^Source:\s*(\S+)", t, re.M)
    if not m or m.group(1) == "none":
        continue
    url = m.group(1)
    d = re.search(r"^Source-SHA256:\s*([0-9a-f]{64})\s*$", t, re.M)
    tb = os.path.join(CACHE, os.path.basename(url))
    if not d:
        nohash += 1
        continue                       # still v1; conversion supplies it
    if not os.path.exists(tb):
        miss += 1
        problems.append((p, "NOT CACHED", os.path.basename(tb)))
        continue
    actual = sha256(tb)
    if actual != d.group(1):
        bad += 1
        problems.append((p, "HASH MISMATCH",
                         f"declared {d.group(1)[:16]}… cached {actual[:16]}…"))
    else:
        ok += 1

print(f"verified {ok}, not cached {miss}, mismatched {bad}, still v1 (no hash) {nohash}")
if problems:
    print()
    for p, kind, detail in problems:
        print(f"  {p:<26} {kind:<14} {detail}")
