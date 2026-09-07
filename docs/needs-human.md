# Needs a human decision

Packages skipped during conversion because the fix is a judgement call, not a
mechanical one. Each entry says what the definition does, why the v2 spec cannot
express it as-is, and what the options are.

---

## `alsa-lib` 1.2.14 — needs a second source tarball

**Category in triage:** EASY (the triage does not detect multi-source packages —
see the note at the bottom).

`[install]` unpacks a second, separate upstream tarball that no field in the
definition declares:

```
tar: ../alsa-ucm-conf-1.2.14.tar.bz2: Cannot open: No such file or directory
tar: Error is not recoverable: exiting now
```

The build itself succeeds — the library compiles and installs into `$DESTDIR`
correctly. The failure is at the point where the definition reaches for
`alsa-ucm-conf`, the ALSA Use Case Manager configuration, which upstream ships
as its own release.

**Why this is not mechanical:** `huddef-v2-spec.md` defines exactly one
`Source:` with one `Source-SHA256:`. There is no way to declare a second
upstream tarball, so any fix changes either the format or the package.

**Options, in the order I would consider them:**

1. **Add multi-source support to v2.** `Source-1:`/`Source-1-SHA256:`, or make
   `Source:` a list. Cleanest if other packages need it — worth checking before
   deciding, because the answer changes the format for all 245.
2. **Split `alsa-ucm-conf` into its own package** and put it in
   `Build-Depends`. Matches how the repository already treats separable
   components, and needs no format change. It does mean a new package.
3. **Drop the ucm-conf step.** Smallest change, but it silently removes
   configuration that the shipped 1.2.14 package currently contains, so the
   rebuilt package would not match what is deployed.

I have not chosen between these. (1) is a format decision and (2) creates a
package, and both are yours.

**Note on the triage:** `alsa-lib` was classified EASY because the triage checks
for patches, `pip3`, network calls and absolute paths — not for a build section
reaching for a tarball that is not declared. Other EASY packages may hide the
same thing. Worth a scan for `tar -x` / `tar x` inside build sections against a
path the definition never fetched.

---

## `cmake` 4.1.0 — `ccmake` fails to compile; disabling it would drop a shipped binary

**First genuine source-level build failure in E4.** Not definition data, not the
dropped `libuv`, not memory or disk — a toolchain incompatibility.

### Diagnosis

Only the `ccmake` target fails
(`Source/CursesDialog/CMakeFiles/ccmake.dir/.../ccmake.cxx.o`). `cmake`, `ctest`,
`cpack` and `CTestLib` all build.

ncurses defines `NCURSES_BOOL` as a macro expanding to `unsigned char`. cmake's
`cm::enum_set` uses `size_type`, also `unsigned char`. Once `curses.h` is
included, the two constructor signatures become identical and GCC rejects them
with "cannot be overloaded with". The `numeric_limits` redefinition and the
`std_function.h` errors further down the log are the same macro pollution, not
separate faults.

GCC 15.2 is stricter than the compiler cmake 4.1.0 was released against.

### Why this needs a decision

`ccmake` **is** in the shipped package:

```
./opt/hud/bin/cmake
./opt/hud/bin/ctest
./opt/hud/bin/cpack
./opt/hud/bin/ccmake          <-- present
./opt/hud/share/cmake-4.1/Help/manual/ccmake.1.rst
./opt/hud/share/envvar/CCMAKE_COLORS.rst
```

So the v1 build did **not** hit this — it compiled `ccmake` successfully against
whatever toolchain built it. Adding `-DBUILD_CursesDialog=OFF` would therefore
make the rebuilt package ship *less* than the one in the pool, which is exactly
the "builds but disables features" outcome this repository's `CLAUDE.md` warns
about. That is a deliberate reduction in scope, not a mechanical fix, so it is
not applied automatically.

### Recommendation

**Disable it:** add `-DBUILD_CursesDialog=OFF` to `[configure]`.

`ccmake` is an interactive ncurses TUI for editing a CMake cache by hand. A build
server never runs it, and nothing in this distribution depends on it — it
provides no library, no pkg-config file and no soname. Losing it costs an
interactive convenience on a machine with no interactive users.

The alternative is patching cmake's `enum_set` or ncurses' macro out of the way,
which means carrying a local patch against upstream C++ for a binary nobody runs.

### If accepted

```
[configure]
... existing flags ...
             -DBUILD_CursesDialog=OFF
```

and note in the definition why, so the next person does not "fix" it back.

`cmake` is deferred to the retry pass at the end of E4.

---

## Toolchain-strictness failures: `gdb`, `git`, `lcms2` (and `cmake`)

Same family as the `cmake`/`ccmake` entry above: these built in 2026-02 and do
not build today. Nothing about the conversion changed them — GCC 15.2 is
stricter than the compiler that produced the shipped packages.

| Package | Failure |
|---|---|
| `git` | `builtin/archive.c:112:15: error: implicit declaration of function 'write_archive'` — GCC 15 defaults to C23, where an implicit declaration is an error rather than a warning |
| `gdb` | `make[1]: *** [Makefile:11734: all-gdb] Error 2` |
| `lcms2` | `make[1]: *** [Makefile:464: tificc] Error 1` — the `tificc` tool, not the library |
| `cmake` | `ccmake` only; ncurses `NCURSES_BOOL` macro collides with `cm::enum_set::size_type` |

Two of the four are a single auxiliary binary failing while the library and the
main tools build: `cmake`'s `ccmake` and `lcms2`'s `tificc`. Those have the same
shape of answer — disable the sub-target or patch it — and the same cost, which
is that the rebuilt package ships less than the pool copy.

`git` and `gdb` are whole-package failures and need real fixes: either upstream
patches for C23 conformance, or `-std=gnu17` in `[configure]`, which is the
conventional workaround for exactly this and is honest about what it is.

**Recommendation:** add `-std=gnu17` to `CFLAGS` for `git` and `gdb` rather than
patching upstream C, and treat `cmake`/`lcms2` as the sub-target decision already
described. All four are deferred to the retry pass.

**This class will grow.** Every package still to build was compiled against an
older toolchain, and roughly 3 % of those attempted so far have failed this way.

---

## `vim` 9.1.0 — configure spins at 100% CPU and never finishes

Not a compile error and not definition data. `./configure` enters an infinite
loop and had to be killed after 11 minutes at **99.6% CPU**, with the log frozen
at `>>> [configure]` and nothing written after it.

```
462   11:25  99.6  /bin/sh /build/vim-9.1.0/configure --prefix=/opt/hud
                   --with-features=huge --enable-multibyte --enable-cscope
                   --disable-gui --without-x --with-tlib=ncurses ...
```

The build had a four-hour timeout, so left alone it would have burned four hours
and then failed anyway.

### Where to look

`--with-tlib=ncurses` is the first suspect. vim's terminal-library probe runs a
test program and some paths loop when the library is found but does not behave as
the probe expects — plausible here, since ncurses comes from `/opt/hud` with
`CPPFLAGS="-I/opt/hud/include -I/opt/hud/include/ncurses"` rather than a standard
location.

Worth trying, in order:

1. Reproduce interactively and find the last line of `config.log` — that names the
   check it is stuck in, which this run never captured because the container was
   killed.
2. Drop `--with-tlib=ncurses` and let configure detect the terminal library.
3. `--with-tlib=tinfo` if ncurses was built with a separate tinfo.

### Recommendation

Do not disable a feature to work around this. Unlike `ccmake` or `tificc`, the
loop is in the probe rather than in a component we could drop, so the fix is to
make the probe succeed. This needs someone to run configure by hand and read
`config.log`; it is not a mechanical fix and not a candidate for the sub-target
precedent.

`vim` is deferred. Everything else in the batch continued normally.

---

## E5/E6 — 33 of the 66 empty `python3-*` packages need three backends that are not packaged

**This is the one decision that gates the rest of E5/E6, and it is a scope
question rather than a technical one: it means creating new packages.**

33 of the 66 were fixed, built, install-tested and published to unstable. The
other 33 cannot be built at all, because the Python build backend each one
declares does not exist in this distribution.

### What the build root actually provides

Measured, not assumed. Every one of the 66 declares `python3` in its
dependencies, so `hud-build` installs the hud `python3` package into the build
root. That interpreter is `/opt/hud/bin/python3`, and its `sys.path` does **not**
include `/usr/lib/python3.13/site-packages` — so nothing the base LFS system
carries is visible to the build:

```
/opt/hud/lib/python313.zip
/opt/hud/lib/python3.13
/opt/hud/lib/python3.13/lib-dynload
/root/.local/lib/python3.13/site-packages
/opt/hud/lib/python3.13/site-packages
```

With `python3` and `python-setuptools` installed, exactly one build backend is
importable — `setuptools`. `wheel`, `flit_core`, `packaging` and `calver` are
all `ModuleNotFoundError`.

### The three missing backends, and what each blocks

| Missing | Blocks | Packages |
|---|---|---|
| `flit_core` | 18 | `alabaster`, `build`, `cachecontrol`, `docutils`, `editables`, `idna`, `pathspec`, `pyparsing`, `pyproject-hooks`, `pyproject-metadata`, `roman-numerals-py`, `sphinx`, and the six `sphinxcontrib-*` |
| `packaging` | 14 | `attrs`, `charset-normalizer`, `hatch-fancy-pypi-readme`, `hatch-vcs`, `hatchling`, `iniconfig`, `meson-python`, `numpy`, `pluggy`, `pygments`, `pytest`, `setuptools-scm`, `typogrify`, `urllib3` |
| `calver` | 1 | `trove-classifiers` |

The three are the roots of the whole tree. `hatchling` — the backend for eight
of the 66 — declares `requires = []` and builds itself through `backend-path`,
so it imports its *own* runtime dependencies while building: `pathspec` (needs
flit_core), `pluggy` (needs `setuptools_scm`, which needs `packaging`),
`trove_classifiers` (needs `calver`), and `packaging` directly. Package the
three roots and the other 30 unblock in dependency order; leave them and none of
the 33 can be built, no matter what order they are attempted in.

The dependency data is derived from each package's own `pyproject.toml` in the
cached tarball — `[build-system] requires` for what pip needs to load the
backend, `[project] dependencies` for what a self-hosting backend imports while
running — with environment markers evaluated by `packaging.markers` against
Python 3.13 rather than pattern-matched. `tomli` and `typing-extensions` appear
in the raw requirement strings and are **not** blockers: both are marked
`python_version < "3.11"`. Full data in `/var/hud-build/e5/plan2.json` on
bf-build.

### Recommendation — package the three

`flit_core`, `packaging` and `calver` are small, pure-Python, and all three
build with nothing but `setuptools`, which is available. `flit_core` is
explicitly designed to bootstrap itself. So the work is three ordinary
definitions, and it unblocks 33 packages including the whole Sphinx
documentation chain and numpy.

The alternative is worse in every direction:

- **Drop `python3` from `Build-Depends`** so the base system's interpreter is
  used. That would work today and must not be done — see the contamination note
  below. It builds against modules this repository does not ship and cannot
  reproduce.
- **Vendor the backends into the build rootfs.** Same objection, plus it makes
  the rootfs, rather than the definitions, the thing that has to be reproduced.
- **Rewrite 33 definitions to install by hand** instead of through PEP 517.
  Diverges from what upstream builds, for 33 packages, permanently.

**Precedent this would follow:** F3 already split `alsa-ucm-conf` into its own
package rather than change the format or ship less. This is the same shape of
answer — create the package the build genuinely needs — at three packages
instead of one. It is not applied automatically because creating distribution
packages expands what G1 must rebuild, what G2 must graph, and what eventually
must be signed.

### Related finding: the build rootfs carries the payloads that never shipped

Worth recording next to this, because it is the same defect seen from the other
side and it looks like an easy way out of the above.

`/usr/lib/python3.13/site-packages` in the golden rootfs contains **exactly 66
dist-info directories dated 2026-01-28, matching the 66 empty packages
one-for-one** — no more, no fewer. They were installed by pip. That is where the
payloads went: the `[install]` sections ran pip without `--root=$DESTDIR`, so
every one of them installed into the build server's own Python, and that
server's filesystem later became the base rootfs.

It does **not** currently make builds pass spuriously, because installing the
hud `python3` package takes `/usr/lib/python3.13/site-packages` off `sys.path`
entirely. It would start to matter the moment a package builds Python code
*without* declaring `python3`, and it is the reason the "just drop `python3`
from Build-Depends" shortcut above must be refused: it would build the fixed
packages against the broken ones' escaped payloads.

The genuine base-system Python packages are the eleven dated 2025 —
`cffi`, `cryptography`, `flit_core`, `jinja2`, `markupsafe`, `meson`,
`packaging`, `pip`, `pycparser`, `setuptools`, `wheel`. Note that `flit_core`
and `packaging` are among them: the base LFS system has both, and only
`/opt/hud` lacks them.

### Also fixed on the way, and worth knowing

`/opt/hud/lib/python3.13/site-packages/setuptools` in the build root is
**gutted** — a `setuptools-80.9.0.dist-info` sitting next to a `setuptools`
package that has no `build_meta` and no `__version__`. Every setuptools-backed
build died with `BackendUnavailable: Cannot import 'setuptools.build_meta'`
until `python-setuptools` was added to `Build-Depends`; the shipped package is
intact at 938 files and installing it repairs the tree. This is very likely a
casualty of the F6 rootfs shrink and may well affect non-Python packages that
run `setup.py` during configure.

---

## E7 — ten packages need one decision about who owns `/etc`, not ten decisions

Ten of the twenty-four ABSOLUTE-PATH packages were fixed mechanically under
`CLAUDE.md` rule 5 and are done. The other ten are blocked on the same question,
asked thirty-five times.

Four of the original twenty-four are **triage false positives** and need
nothing: `postgresql-ha`, `postgresql-ldap` and `postgresql-ldap-ha` were
matched on `ExecStartPre=/bin/mkdir -p /run/postgresql`, a line *inside* a
systemd unit being written into `$DESTDIR`; `python3-py3c` on `make
prefix=/opt/hud install`, which stages correctly because hud-build exports
`DESTDIR` and autotools honours it. The real category is 20.

Full inventory in `docs/e7-inventory.json`; regenerate with
`scripts/e7-scan.py`.

### The question

Rule 5 says a config file belongs in `[install]` under `$DESTDIR`, shipped as a
`.default` and copied by `[postinst]` only if the target is absent. That rule
was written for a config file the package owns. These thirty-five writes are not
all that, and three groups genuinely differ:

**1. systemd units in `/etc/systemd/system/` — 13 writes, 5 packages.**
`/etc/systemd/system` is the *administrator's* directory; a package's own units
belong in `/usr/lib/systemd/system` (or `/opt/hud/lib/systemd/system`, which is
what `dhcpcd` uses and what E7 shipped for it). Writing a package unit into
`/etc/systemd/system` means it outranks anything the admin puts there and cannot
be overridden the normal way. **Recommendation: ship them under
`/opt/hud/lib/systemd/system` like dhcpcd, and add that directory to systemd's
unit path once, rather than per package.** That second half is a distribution
decision, which is why this is here.

**2. Admin-editable config — 14 writes, 7 packages.** `/etc/pam.d/system-auth`,
`/etc/libvirt/*.conf`, `/etc/NetworkManager/*`, `/etc/dnsmasq.conf`,
`/etc/nftables/nftables.conf`, `/etc/firewalld/firewalld.conf`,
`/etc/qemu/bridge.conf`. Rule 5's `.default` pattern fits these, but two things
need saying out loud before applying it thirty-five times:

- `/etc/pam.d/*` is **shared, and getting it wrong locks everyone out.** v1
  overwrites `system-auth`, `system-account`, `system-session`,
  `system-password` and `other` unconditionally on every install of
  `linux-pam`. That is the highest-risk write in the whole set and should not be
  changed by a script.
- **`firewalld` and `libvirt` both write `/etc/firewalld/zones/libvirt.xml`.**
  Two packages, one file, whichever installs last wins. Under the `.default`
  scheme they would ship two files with the same path and conflict at install
  time — which is better than silently overwriting, but it is still a
  package-boundary question: the zone describes libvirt, so it should probably
  ship with `libvirt` alone.

**3. Executables written into `/usr/bin` — 6 writes, 3 packages.**
`firewalld` writes a `firewall-cmd` wrapper into `/usr/bin` and chmods it;
`libvirt` chmods `/usr/bin/virsh`; both `libvirt` and `networkmanager` write
polkit rules into `/usr/share/polkit-1/rules.d/`. These are not config and not
symlinks — they are program files placed outside the prefix by a shell script at
install time, and nothing tracks or removes them. **Recommendation: ship the
wrapper as a real file in `[install]` under `$DESTDIR/usr/bin`, and ship the
polkit rules the same way.** The `chmod /usr/bin/virsh` is dead code — libvirt
installs `virsh` to `/opt/hud/bin`.

### Why this is one decision and not ten

Every one of the thirty-five is an instance of "may a hud package own a file
outside `/opt/hud`, and if so which directories". Answer that once and the ten
packages are mechanical, like the first ten were. Answer it per package and the
tree ends up with three conventions.

The FHS-versus-`/opt/hud` decision in the hard gate is the same question at
larger scale, so this is worth settling before it, not after.

### What was done meanwhile

The ten mechanical ones are converted, fixed, built and published to unstable.
Two findings from them that do not depend on this decision:

- **`docbook-xsl` shipped nothing.** Its `[install]` wrote every path as an
  absolute `/opt/hud` path with no `$DESTDIR`, so the stylesheets went into the
  build container. Fixed, and the package went from 5 KB to 24 MB. **The
  under-5 KB check that found the 66 empty python3-* packages should be run
  against all 245**, because this one was not a `python3-*` and nothing was
  looking for it.
- **`openldap`'s `.la`-to-`.so` sed ran against `/etc/openldap` on the build
  host** while `make install` had just written those files into `$DESTDIR`, so
  the shipped `slapd.conf` still names `.la` files that are not installed.
