#!/usr/bin/env python3
"""
Dependency order for a full rebuild (G1).

Orders packages by Build-Depends — what has to exist before a build can start —
not by Depends, which is what the package needs at runtime. The two differ a
great deal here: `Depends: auto` resolves to capability strings, and v1's
Depends mixed build and runtime freely, which is why dav1d "depended on"
meson and ninja.

Cycles are reported, not broken. A cycle in Build-Depends is a real bootstrap
problem and silently picking an order hides it.
"""
import json, os, re, sys

H = "huddefs"


def build_depends(pkg):
    f = f"{H}/{pkg}/{pkg}.huddef"
    if not os.path.exists(f):
        return None
    s = open(f, errors="replace").read()
    m = re.search(r"^Build-Depends:[ \t]*(.*)$", s, re.M)
    if m is None:
        # still v1: fall back to Depends, which is what the conversion does
        m = re.search(r"^Depends:[ \t]*(.*)$", s, re.M)
    if m is None:
        return []
    return [d.strip() for d in m.group(1).split(",")
            if d.strip() and d.strip().lower() != "auto"]


def main():
    pkgs = sorted(p for p in os.listdir(H)
                  if os.path.exists(f"{H}/{p}/{p}.huddef"))
    known = set(pkgs)
    edges, external = {}, {}
    for p in pkgs:
        bd = build_depends(p) or []
        inside = sorted({d for d in bd if d in known and d != p})
        outside = sorted({d for d in bd if d not in known})
        edges[p] = set(inside)
        if outside:
            external[p] = outside

    # Kahn, alphabetical among ready nodes so the order is reproducible.
    remaining = {p: set(v) for p, v in edges.items()}
    order, done = [], set()
    ready = sorted(p for p in pkgs if not remaining[p])
    while ready:
        n = ready.pop(0)
        order.append(n)
        done.add(n)
        newly = []
        for p, deps in remaining.items():
            if p in done or n not in deps:
                continue
            deps.discard(n)
            if not deps:
                newly.append(p)
        ready = sorted(ready + newly)

    stuck = [p for p in pkgs if p not in done]
    cycles = {p: sorted(remaining[p]) for p in stuck}

    out = {"order": order, "cycles": cycles,
           "external_build_depends": external,
           "counts": {"packages": len(pkgs), "ordered": len(order),
                      "in_cycles": len(stuck)}}
    dest = sys.argv[1] if len(sys.argv) > 1 else "/var/hud-build/build-order.json"
    json.dump(out, open(dest, "w"), indent=1)
    print(f"{len(pkgs)} packages, {len(order)} ordered, {len(stuck)} in cycles -> {dest}")
    if cycles:
        print("\nCYCLES (not broken — these are real bootstrap problems):")
        for p, d in sorted(cycles.items()):
            print(f"  {p:<26} waits on {d}")
    if external:
        print(f"\n{len(external)} packages name a Build-Depends that is not a package here:")
        seen = {}
        for p, ds in external.items():
            for d in ds:
                seen.setdefault(d, []).append(p)
        for d, ps in sorted(seen.items()):
            print(f"  {d:<22} {len(ps)}x  {ps[:4]}")


if __name__ == "__main__":
    main()
