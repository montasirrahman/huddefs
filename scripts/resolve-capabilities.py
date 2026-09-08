#!/usr/bin/env python3
"""
Turn derived capabilities into the package names the hud client can resolve.

`Depends: auto` derives capabilities — libxml2.so.16, pkgconfig(zlib),
python3dist(cssselect), exec(perl). The deployed client looks every Depends
entry up as a PACKAGE NAME, so it warns "Dependency not in repository" and
installs nothing. Demonstrated: python3-lxml installs while libxml2, libxslt and
zlib do not, and hud install exits 0.

So the capability stays in `Requires:`, which is what the capability graph reads
and what makes soname bumps visible, and `Depends:` gets the package names.

Resolution order, most specific first:
  1. the soname map built from the published pool (build-soname-map.sh)
  2. the pkg-config, header and binary maps in provmap.json
  3. python3dist(X) -> python3-X or python-X if such a package exists
  4. base-system capabilities are dropped: libc.so.6 and friends come from the
     LFS base, no hud package provides them, and naming them would produce the
     same "not in repository" warning this exists to remove

Anything left unresolved is reported on stderr and dropped from Depends rather
than passed through — passing it through is the current defect.

    resolve-capabilities.py "libxml2.so.16,libz.so.1,exec(perl)"
"""
import json, os, re, sys

SONAME_MAP = os.environ.get("HUD_SONAME_MAP", "/var/hud-build/sonamemap.json")
PROV_MAP   = os.environ.get("HUD_PROV_MAP",  "/var/hud-build/e4/provmap.json")
REPO_INDEX = os.environ.get("HUD_REPO_INDEX", "/var/www/hud-unstable/packages.list")
REPO_URLS  = ("http://172.19.1.7/hud-unstable/packages.list",
              "http://172.19.1.7/hud-repo/packages.list")

# Supplied by the base BlackFlag system. No hud package provides these and none
# should — /opt/hud duplicates the LFS toolchain rather than replacing it.
BASE_SYSTEM = {
    "libc.so.6", "libm.so.6", "libdl.so.2", "libpthread.so.0", "librt.so.1",
    "libutil.so.1", "libcrypt.so.2", "libresolv.so.2", "libanl.so.1",
    "libgcc_s.so.1", "libstdc++.so.6", "libatomic.so.1", "libgomp.so.1",
    "ld-linux-x86-64.so.2", "libnsl.so.3", "libmvec.so.1", "libthread_db.so.1",
    "exec(sh)", "exec(bash)", "exec(awk)", "exec(sed)", "exec(env)",
}


def load_json(path):
    try:
        return json.load(open(path))
    except Exception:
        return {}


def repo_names():
    for p in (REPO_INDEX, "/var/www/hud-repo/packages.list"):
        try:
            text = open(p).read()
        except OSError:
            continue
        return {l.split("|")[0] for l in text.splitlines()
                if l and not l.startswith("#") and "|" in l}
    for u in REPO_URLS:
        try:
            import urllib.request
            with urllib.request.urlopen(u, timeout=15) as fh:
                text = fh.read().decode("utf-8", "replace")
            return {l.split("|")[0] for l in text.splitlines()
                    if l and not l.startswith("#") and "|" in l}
        except Exception:
            continue
    return set()


def main():
    caps = [c.strip() for c in (sys.argv[1] if len(sys.argv) > 1 else "").split(",")
            if c.strip()]
    sonames = load_json(SONAME_MAP)
    prov = load_json(PROV_MAP)
    pc, hdr, binm = prov.get("pc", {}), prov.get("hdr", {}), prov.get("bin", {})
    have = repo_names()

    out, unresolved = [], []
    for cap in caps:
        if cap in BASE_SYSTEM:
            continue
        hit = None
        if cap in sonames:
            hit = sonames[cap]
        else:
            m = re.fullmatch(r"pkgconfig\((.+)\)", cap)
            if m and m.group(1) in pc:
                hit = pc[m.group(1)]
            m = m or re.fullmatch(r"exec\((.+)\)", cap)
            if hit is None and m and m.group(1) in binm:
                hit = binm[m.group(1)]
            if hit is None:
                m = re.fullmatch(r"python3dist\((.+)\)", cap)
                if m:
                    for cand in (f"python3-{m.group(1)}", f"python-{m.group(1)}"):
                        if cand in have:
                            hit = cand
                            break
            if hit is None and cap in have:
                hit = cap          # already a package name
        if hit and (not have or hit in have):
            if hit not in out:
                out.append(hit)
        else:
            unresolved.append(cap)

    if unresolved:
        print("unresolved capabilities (dropped from Depends, still in Requires): "
              + ", ".join(unresolved), file=sys.stderr)
    print(",".join(sorted(out)))


if __name__ == "__main__":
    main()
