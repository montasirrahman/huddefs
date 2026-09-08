# The Python bootstrap: three packages that unblocked thirty-three

Resolved 2026-09-08.

## What was blocked, and why no ordering fixed it

66 `python3-*` packages shipped nothing: their `[install]` ran pip without
`--root=$DESTDIR`, so the payload went into the build container's own Python.
The fix is mechanical, and 33 of them were fixed that way. The other 33 could not
be built **in any order**, because the PEP 517 backend each one declares did not
exist in this distribution.

The measurement that settled it: every one of the 66 declares `python3`, so
`hud-build` installs the hud `python3` package, and *that* interpreter is
`/opt/hud/bin/python3`, whose `sys.path` is

```
/opt/hud/lib/python313.zip
/opt/hud/lib/python3.13
/opt/hud/lib/python3.13/lib-dynload
/root/.local/lib/python3.13/site-packages
/opt/hud/lib/python3.13/site-packages
```

**`/usr/lib/python3.13/site-packages` is not on it.** The base system's
`flit_core`, `packaging` and `wheel` are real and reachable from `/usr/bin/python3`
and completely invisible to a build. With `python3` and `python-setuptools`
installed, `setuptools` was the only importable backend.

`flit_core` blocked 18, `packaging` 14, `calver` 1. They are the roots of the
tree rather than leaves of it: `hatchling` declares `requires = []` and builds
itself through `backend-path`, so while running as a backend it imports
`pathspec` (flit_core), `pluggy` (setuptools_scm → packaging) and
`trove_classifiers` (calver).

## The three, and why they bootstrap in this order

Each was checked against its own `pyproject.toml`, not assumed:

| Package | `build-system.requires` | Backend | Order |
|---|---|---|---|
| `python3-flit-core` | `[]` | `flit_core.buildapi`, `backend-path ["."]` | first — builds itself |
| `python3-packaging` | `flit_core >=3.3` | `flit_core.buildapi` | after flit_core |
| `python3-calver` | `setuptools>=77.0.1` | `setuptools.build_meta` | any time |

`flit_core` is where it starts precisely because it needs nothing that is not
already present — pip loads the backend straight out of the source tree.

Built and published:

```
python3-flit-core   116,836 bytes   39 payload files   also provides python3dist(tomli)
python3-packaging   156,331 bytes   43 payload files
python3-calver        9,719 bytes   14 payload files
```

After which the plan recomputes to **66 buildable, 0 blocked.**

## Why the base system's copies must not be used instead

The tempting shortcut is to drop `python3` from `Build-Depends` so the base
interpreter is used, since it has all three. It must be refused.
`/usr/lib/python3.13/site-packages` contains **exactly 66 pip-installed
dist-info directories dated 2026-01-28, matching the 66 empty packages
one-for-one** — the payloads that escaped when pip ran without `--root`. Building
against them means building against the very defect being fixed, and against
modules this repository does not ship and cannot reproduce.
`docs/rootfs-audit.md` has the detail.

## Sources

Fetched from PyPI over https and added to `/var/hud-build/cache`, so G1 still
runs with no network:

```
flit_core-3.12.0.tar.gz    18f63100d6f94385c6ed57a72073443e1a71a4acb4339491615d0f16d6ff01b2
packaging-25.0.tar.gz      d443872c98d677bf60f6a1f2f8c1cb748e8fe762d2bf9d3148b5599295b0fc4f
calver-2025.4.17.tar.gz    460702737d620f5c3d4175450485180a1b7f7a422c5db0e6af3e655c7395ec7e
```

Versions match the base system's, so a package built against `/opt/hud`'s copy
behaves as it did against the base one.
