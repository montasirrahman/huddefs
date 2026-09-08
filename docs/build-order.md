# G1 build order, and the cycle it exposes

`scripts/build-order.py` orders every definition by `Build-Depends` — what must
exist before a build can start — rather than by `Depends`, which is what the
package needs at runtime. The two are not interchangeable here: `Depends: auto`
resolves to capability strings rather than package names, and v1's `Depends`
mixed build and runtime freely, which is why `dav1d` "depended on" meson and
ninja.

```bash
./scripts/build-order.py /var/hud-build/build-order.json
```

Cycles are reported, never broken by picking an order. A cycle in `Build-Depends`
is a real bootstrap problem, and silently choosing a starting point hides it.

## RESOLVED 2026-09-09: 250 packages, all 250 ordered, no cycles

`cmake` now bootstraps with `--no-system-curl`, which cuts the loop, and
`patchelf` is packaged, which removes the last unpackaged `Build-Depends`.
`python-setuptools` named `python`, the base system's name for `python3`.

```
250 packages, 250 ordered, 0 in cycles
```

Cutting at cmake rather than brotli was forced: brotli 1.1.0 has no build system
but cmake, so it cannot be built first. cmake's bundled curl is reachable only
through `file(DOWNLOAD)` and `ctest_submit`, neither of which any build here
uses — the network is disabled during builds. The cost is that cmake's curl does
not get security updates with the system one, and **the proper answer is a
second pass: rebuild cmake against system curl once curl exists.** G1 should do
that, and until it does the trade is written down rather than implied.

The original analysis follows, because it explains why the cycle existed and why
it was invisible for so long.

---

## (original) Result: 246 packages, 221 orderable, 25 behind one cycle

```
cmake   ->  curl
curl    ->  brotli
brotli  ->  cmake
```

Three packages, and 22 more wait behind them: `aom`, `cups`, `dejavu-fonts`,
`fontconfig`, `git`, `harfbuzz`, `java-bin`, `json-c`, `lcms2`,
`liberation-fonts`, `libibverbs`, `libjpeg`, `libjpeg-turbo`, `libtiff`,
`libvirt`, `libwebp`, `libzip`, `networkmanager`, `nodejs`, `openjdk`,
`rdma-core`, `yajl`.

**This cycle was invisible until 2026-09-07.** The `curl -> brotli` edge is one
of the dependencies that `repo_names()` had silently deleted; restoring the 55
damaged definitions restored the edge, and with it the cycle.

## Why nothing has failed because of it

`curl`, `brotli` and `zlib` are three of the **nine bootstrap-floor packages**
that the minimal rootfs always contains, because the hud client cannot fetch
anything without them. So every build already starts with curl and brotli
present, and the cycle never has to be resolved at build time.

That is also exactly why it went unnoticed, and why it matters for G1: **the
three packages in the cycle are the three whose `Build-Depends` a build can never
validate.** A G1 run that starts from the current minimal rootfs will report all
245 green without ever having tested whether this cycle can be bootstrapped.

## What G1 has to decide

A genuine from-scratch rebuild has to break the cycle somewhere. In rough order
of preference:

1. **Build `brotli` without cmake.** brotli ships a plain `Makefile` alongside
   its CMake build. If that works, the cycle is cut at its cheapest edge and
   nothing else changes.
2. **Build `cmake` without curl** — `-DCMAKE_USE_SYSTEM_CURL=OFF`, using the
   curl cmake bundles. Standard bootstrap practice, but it means the first cmake
   differs from the shipped one and would want rebuilding afterwards.
3. **Declare the bootstrap floor explicitly** — treat the nine as a
   pre-existing base that G1 does not rebuild, and say so. Honest, and it is
   what happens today, but it leaves nine packages permanently unverified.

(1) then (3) is the recommendation: cut the cycle properly, and be explicit
about what the floor is either way.

**`cmake` also does not build today** — `ccmake` fails against GCC 15.2, logged
in `needs-human.md`. So the head of the cycle is blocked twice over, and that
should be settled before G1 rather than during it.

## Build-Depends naming something that is not a package here

Six entries survive normalisation but match no definition:

| Name | Named by | Note |
|---|---|---|
| `bootscripts` | `cyrus-sasl`, `openldap` | LFS bootscripts; this distribution uses systemd |
| `mariadb` | `cyrus-sasl`, `openldap` | optional backend, never packaged |
| `libuv` | `nodejs` | node bundles its own |
| `patchelf` | `python3-meson-python` | not packaged |
| `python` | `python-setuptools` | base system; the package is `python3` |
| `xorg-libs` | `java-bin` | book collective name, not a package |

All six fall under the standing precedent — a declared dependency the repository
does not have is presumed invalid — and are recorded in `docs/dropped-deps.json`.
