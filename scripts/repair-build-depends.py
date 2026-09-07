#!/usr/bin/env python3
"""
Restore Build-Depends that repo_names() dropped when it could not find the index.

convert-easy.py's repo_names() read /var/www/hud-repo/packages.list, which
exists only on bf-repo, and swallowed OSError. Once building moved to bf-build
the index was absent, the name dictionary stayed empty, and normalise_deps()
concluded that every declared dependency was absent from the repository and
dropped it — silently, with green builds, because the base rootfs supplies
enough for many packages to configure anyway.

This rebuilds the field from the v1 definition in git history: take the earliest
committed form of each file, normalise its Depends against a real index, and
merge with whatever the current file has (which includes anything hud-build's
retry logic added and must not be lost).

Idempotent: a second run finds nothing missing and rewrites nothing.
"""
import json, os, re, subprocess, sys

H = "huddefs"

# Same resolution order as convert-easy.py's repo_names(). The index lives on
# bf-repo, and this script has to run wherever the definitions were converted —
# which is bf-build. Defaulting to a bf-repo-only path is the exact mistake
# being repaired here.
INDEX_CANDIDATES = (
    "/var/www/hud-unstable/packages.list",
    "/var/www/hud-repo/packages.list",
    "http://172.19.1.7/hud-unstable/packages.list",
    "http://172.19.1.7/hud-repo/packages.list",
)
INDEX = sys.argv[1] if len(sys.argv) > 1 else None


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout


def read_index(src):
    if src.startswith("http://") or src.startswith("https://"):
        import urllib.request
        with urllib.request.urlopen(src, timeout=20) as fh:
            return fh.read().decode("utf-8", "replace")
    return open(src).read()


def load_index(path=None):
    for src in ([path] if path else INDEX_CANDIDATES):
        try:
            text = read_index(src)
        except Exception:
            continue
        have = {}
        for line in text.splitlines():
            if not line.startswith("#") and "|" in line:
                n = line.split("|")[0]
                have[n.lower()] = n
        if have:
            print(f"index: {src} ({len(have)} names)")
            return have
    raise RuntimeError("no repository index found; tried "
                       + ", ".join([path] if path else INDEX_CANDIDATES))


def normalise(deps, have):
    keep, drop = [], []
    for d in deps:
        dl = d.lower()
        hit = None
        for cand in (dl, dl.rstrip("0123456789"), dl.replace("-", ""), dl + "2"):
            if cand in have:
                hit = have[cand]
                break
        if hit:
            if hit not in keep:
                keep.append(hit)
        else:
            drop.append(d)
    return keep, drop


def main():
    have = load_index(INDEX)
    changed, unchanged, skipped = [], 0, 0
    for p in sorted(os.listdir(H)):
        f = f"{H}/{p}/{p}.huddef"
        if not os.path.exists(f):
            continue
        cur = open(f, errors="replace").read()
        m = re.search(r"^Build-Depends:[ \t]*(.*)$", cur, re.M)
        if not m:
            skipped += 1          # still v1; conversion will handle it
            continue
        now = [x.strip() for x in m.group(1).split(",") if x.strip()]

        first = sh(f"git log --format=%H --reverse -- {f} | head -1").strip()
        if not first:
            continue
        old = sh(f"git show {first}:{f}")
        om = re.search(r"^Depends:[ \t]*(.*)$", old, re.M)
        if not om:
            continue
        v1 = [x.strip() for x in om.group(1).split(",")
              if x.strip() and x.strip().lower() != "auto"]
        should, dropped = normalise(v1, have)
        merged = should + [x for x in now if x not in should]
        if merged == now:
            unchanged += 1
            continue
        new = re.sub(r"^Build-Depends:[ \t]*.*$",
                     "Build-Depends:    " + ", ".join(merged), cur, count=1, flags=re.M)
        open(f, "w").write(new)
        changed.append((p, [x for x in should if x not in now], dropped))

    print(f"repaired {len(changed)}, already correct {unchanged}, still v1 {skipped}")
    for p, restored, dropped in changed:
        print(f"  {p:<24} +{restored}" + (f"   (not in repo: {dropped})" if dropped else ""))


if __name__ == "__main__":
    main()
