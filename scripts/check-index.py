#!/usr/bin/env python3
"""
Check that every dependency in the index names a package the index has.

The client resolves each Depends entry as a package name and, when it finds
nothing, warns and carries on — then installs anyway and exits 0. So an
unresolvable entry is invisible at install time and shows up later as a package
that cannot load. This is the check that would have caught the capability-string
defect the day it appeared.

    check-index.py [packages.list]
"""
import collections, sys

INDEX = sys.argv[1] if len(sys.argv) > 1 else "/var/www/hud-unstable/packages.list"

rows, names = [], set()
for line in open(INDEX):
    if line.startswith("#") or "|" not in line:
        continue
    f = line.rstrip("\n").split("|")
    if len(f) < 7:
        continue
    rows.append((f[0], f[1], f[6]))
    names.add(f[0])

bad = collections.defaultdict(list)
caps = collections.defaultdict(list)
for name, ver, deps in rows:
    for d in (x.strip() for x in deps.split(",")):
        if not d:
            continue
        if d in names:
            continue
        # a capability rather than a package name — the specific defect
        if ".so." in d or d.startswith(("exec(", "pkgconfig(", "python3dist(")):
            caps[name].append(d)
        else:
            bad[name].append(d)

print(f"{len(rows)} index rows, {len(names)} package names")
print(f"{sum(len(v) for v in caps.values())} capability strings in "
      f"{len(caps)} packages  (the client cannot resolve these at all)")
for k in sorted(caps):
    print(f"    {k}: {', '.join(caps[k][:5])}")
print(f"{sum(len(v) for v in bad.values())} names in {len(bad)} packages "
      f"that no package in this index provides")
for k in sorted(bad):
    print(f"    {k}: {', '.join(sorted(set(bad[k]))[:8])}")

sys.exit(1 if (caps or bad) else 0)
