# G2 — the capability graph

```bash
./scripts/hud-graph-build [POOL] [GRAPH.db]     # default: unstable pool -> /var/hud-build/graph.db
./scripts/hud-graph deps     <pkg>
./scripts/hud-graph rdeps    <pkg>
./scripts/hud-graph why      <a> <b>
./scripts/hud-graph orphans
./scripts/hud-graph missing
./scripts/hud-graph provides <cap>
./scripts/hud-graph stats
```

## Why it is not a package-to-package graph

The shipped client answers reverse dependencies with

```sql
SELECT ... WHERE depends LIKE '%pkg%'
```

which matches `libX11` inside `libX11-xcb`, matches any package whose
description happens to contain the name, and misses a dependency recorded as a
soname. **There is no `LIKE` anywhere in `hud-graph`, and there should never
be.** Every lookup is an equality join on a capability string, which is also
what makes the graph survive a package rename and catch a soname bump.

## Two kinds of edge, recorded as such

`requires.kind` is `capability` or `name`, and the distinction is not cosmetic.
huddef v2 emits capabilities — `libssl.so.3` — while every package published
before it recorded bare package names in `Depends`. Storing both in one column
without saying which was which made 367 of 389 required strings look
unprovided, when most were package names being compared against soname rows.
Resolving them by the right join brings that to 104.

Name edges shrink as packages are rebuilt under v2. Today: 126 capability
edges, 263 name edges.

`Provides` is derived from the archive's own file list, not only from the
`Provides:` header — that field arrived with v2, so a graph built from it alone
describes a distribution where almost nothing provides anything. Sonames under
`lib/`, `.pc` files and `.dist-info` directories give the same three capability
kinds the spec defines, for old and new packages alike. That took provides from
48 to 657.

## `missing` separates the base system from the genuinely absent

`libc.so.6`, `libstdc++.so.6`, `exec(sh)` and the rest come from the base LFS
system and no hud package provides them or should. They are listed separately
rather than mixed in, because otherwise the useful signal drowns.

## A defect this found: optional Python extras were hard dependencies

`hud-scan-deps` read every `Requires-Dist:` line out of a `.dist-info/METADATA`
and made each one a requirement, **including the ones that only apply to an
optional extra**. `python3-sentry-sdk` declared 48 requirements, among them
`anthropic`, `aiohttp` and `apache-beam` — none packaged here, none needed for
sentry-sdk to work, and all of them appearing in `hud-graph missing`.

Fixed: a `Requires-Dist` whose marker contains `extra ==` is skipped, as is one
whose `python_version <` marker excludes 3.13. sentry-sdk goes from 48 declared
requirements to **2** — `urllib3` and `certifi` — both of which are real
packages here.

**Packages already built carry the old, inflated `Requires` in their metadata.**
G1 rebuilds them, and the graph should be rebuilt after it.

## Current shape

```
packages                      251
  shipping no payload          34
provided capabilities         599
required, as capabilities     126
  unprovided                  104
required, as package names    263
  naming no known package     111
```

The 34 empty packages are what remains of the 67 the sweep found — 33 have been
fixed and republished, and the rest are the E5/E6 set blocked on `flit_core`,
`packaging` and `calver`. Both numbers should reach zero, and `hud-graph stats`
is the cheapest way to watch them.
