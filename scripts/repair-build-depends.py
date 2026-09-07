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
INDEX = sys.argv[1] if len(sys.argv) > 1 else "/var/www/hud-unstable/packages.list"


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout


def load_index(path):
    have = {}
    for line in open(path):
        if not line.startswith("#") and "|" in line:
            n = line.split("|")[0]
            have[n.lower()] = n
    if not have:
        raise RuntimeError(f"{path} parsed to zero names")
    return have


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
