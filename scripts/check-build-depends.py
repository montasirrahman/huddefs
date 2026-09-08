#!/usr/bin/env python3
"""
Find packages that link a library nothing they declare could have provided.

You cannot link against a library you did not build against. So when the index
says a package's runtime dependencies include X — and those are derived from the
ELF, not from anyone's opinion — X's headers had to be present at build time.

Reporting every such name is too noisy to act on: most are reached transitively
(glusterfs links brotli because it links curl) or come from the bootstrap floor,
the nine packages always present in the minimal rootfs. So this walks the
runtime closure of the declared Build-Depends first, and reports only what falls
outside it *and* outside the floor.

What is left is the libvirt class: libvirt declared no libtirpc, so
/opt/hud/include/tirpc was never installed, the rootfs shim /usr/include/tirpc
dangled, pkg-config fell through to a stale system libtirpc.pc describing
headers that were not there, and the build died on 'rpc/rpc.h: No such file or
directory' one line after meson reported the dependency found.

Survivors are candidates, not verdicts. Several link libraries belonging to the
base OS itself rather than to any hud package — libudev.so.1 is the common one —
which builds correctly and is still worth knowing about, because it means the
build depends on the contents of the root rather than on anything it declares.

Only packages rebuilt in this campaign are checked: everything else still
carries a hand-written v1 dependency list that says nothing about linkage.
"""
import json, os, re, sys

H     = "/root/github-repo/huddefs/huddefs"
INDEX = os.environ.get("HUD_INDEX", "/var/www/hud-unstable/packages.list")
STATE = os.environ.get("E5_STATE", "/var/hud-build/e5-state.json")
SIDE  = "/var/hud-build/e5-state-side.json"

# The nine packages the minimal rootfs always contains. A build may rely on
# these without declaring them; that is what "floor" means.
FLOOR = {"curl", "openssl", "zlib", "zstd", "brotli",
         "nghttp2", "libidn2", "libpsl", "libunistring"}

runtime, section = {}, {}
for line in open(INDEX):
    if line.startswith("#") or "|" not in line:
        continue
    f = line.rstrip("\n").split("|")
    runtime[f[0]] = [d for d in f[6].split(",") if d]
    section[f[0]] = f[7]

rebuilt = set()
for path in (STATE, SIDE):
    try:
        rebuilt |= set(json.load(open(path))["published"])
    except Exception:
        pass
if not rebuilt:
    print("no build state found; nothing has been rebuilt, so linkage says nothing",
          file=sys.stderr)
    sys.exit(0)


def declared(pkg, name):
    f = f"{H}/{pkg}/{pkg}.huddef"
    if not os.path.exists(f):
        return []
    m = re.search(rf"^{name}:\s*(.*)$", open(f, errors="replace").read(), re.M)
    return [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []


def closure(seeds):
    seen, stack = set(), list(seeds)
    while stack:
        p = stack.pop()
        if p in seen:
            continue
        seen.add(p)
        stack.extend(runtime.get(p, []))
    return seen


rows = []
for pkg in sorted(rebuilt):
    # Pure-Python packages declare runtime imports, not linkage; the premise
    # above does not apply to them.
    if section.get(pkg) == "python":
        continue
    bd = declared(pkg, "Build-Depends")
    if not bd:
        continue
    reach = closure(bd) | FLOOR
    missing = [d for d in runtime.get(pkg, []) if d not in reach and d != pkg]
    if missing:
        rows.append((pkg, missing))

for pkg, missing in rows:
    print(f"  {pkg}: links but cannot reach -> {', '.join(missing)}")
print(f"\n{len(rows)} of {len(rebuilt)} rebuilt packages link something "
      f"outside their declared closure and the bootstrap floor")
sys.exit(0)
