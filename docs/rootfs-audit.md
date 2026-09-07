# The minimal build rootfs is not minimal, and it lies about what is installed

Found 2026-09-07, by the G4 boot gate. The gate prints how many packages the
booted image has registered, and it printed **242** for a rootfs documented as
holding nine.

## What F6 actually did

The F6 shrink took a fully populated bf-repo tree from 4.9 G to 3.3 G by
deleting package files. It did not remove the packages. What is left:

```
packages registered in share/hud/info : 242
dangling symlinks                     : 2226   (617 library or pkg-config)
empty directories                     : 1754
real files remaining under /opt/hud   : 5002
```

Each `share/hud/info/<pkg>/` directory survives, holding only its `postinst` —
`PACKAGE` and `FILES` are gone, so nothing can even tell you which files the
package was supposed to own. The client's own database under `/var/lib/hud/db/`
is empty, which is why `hud install` still works: it believes nothing is
installed.

## Why the dangling symlinks matter more than the missing files

A symlink chain survives when its target does not:

```
/opt/hud/lib/pkgconfig/libpng.pc -> libpng16.pc          (gone)
/opt/hud/lib/libpng.so           -> libpng16.so          (gone)
/opt/hud/lib/libpng16.so         -> libpng16.so.16.50.0  (gone)
```

A `configure` test that checks whether `libpng.so` exists finds it, concludes
libpng is available, and then cannot link. That produces exactly the error E4
recorded:

```
freetype  FAIL — configure: error: libpng support requested but library not found
```

609 library symlinks and 8 `.pc` files are in this state, including `ncurses.pc`,
`libX11.so`, `libtiff.so.6`, `libdrm.so`, `libusb-1.0.so` and `libevent_*.so`.
**A build root that answers "yes, present" and then fails to link is worse than
one that answers "no".** In the second case `Build-Depends` gets fixed; in the
first the failure is attributed to the package's source.

This is very likely a shared cause behind several E4 failures previously filed as
toolchain strictness or bad definition data — `freetype`, `libxslt`
("Could not find libxml2 anywhere"), `libvorbis` ("Ogg was incorrectly
installed"), `ncurses`, `pcre2` and `libXt` all have the shape of a dependency
that is half-present.

## Also: `/opt/hud`'s setuptools is one of the casualties

```
/opt/hud/lib/python3.13/site-packages/setuptools/   7 entries, no build_meta,
/opt/hud/lib/python3.13/site-packages/setuptools-80.9.0.dist-info/   intact
```

A dist-info claiming a working setuptools next to a package with its modules
deleted. Every setuptools-backed build failed with
`BackendUnavailable: Cannot import 'setuptools.build_meta'` until E5/E6 added
`python-setuptools` to `Build-Depends`. That was the right fix for the
definitions — a package built by setuptools does depend on setuptools — but the
reason it was needed is here.

## What to do

`scripts/rootfs-audit.sh [ROOT]` reports the numbers above.
`CLEAN=1 scripts/rootfs-audit.sh [ROOT]` additionally deletes every dangling
symlink and every empty directory.

**Cleaning is safe and is not the fix.** A dangling symlink cannot be opened by
anything; its only effect is to make an existence test succeed for a file that
is not there, so removing it cannot break a working build. But 5,002 real files
remain — docbook stylesheets, man pages, openssl headers — and the info database
still lists 242 packages. Cleaning turns a root that lies into a root whose
remaining flaws are enumerated.

**The fix is to regenerate the rootfs by installing the nine bootstrap packages
onto a clean base**, rather than by deleting files from a populated one. Until
that happens:

- **G1 cannot honestly claim a from-scratch rebuild.** It would be building
  against 5,002 files and 242 registered packages it does not control.
- Any `Build-Depends` naming something whose remnants are still present is
  unvalidated, which is the same weakness the nine bootstrap packages already
  have — but for 242 packages instead of nine.

**Never clean a root while an overlay is mounted over it.** `hud-build` uses
`/var/hud-build/roots/minimal` as an overlay `lowerdir`; deleting through it
while a build runs is the failure that corrupted the golden tree in F5.

---

## Which E4 failures this implicates, and which it does not

Every E4 failure checked names a library that is present in the rootfs **as a
dangling symlink**:

```
E4 failure    dangling link it named
freetype      libpng.pc, libpng.so
libxslt       libxml2.so
libvorbis     libogg.so
ncurses       ncurses.pc, libncursesw.so
pcre2         libpcre2-8.so
libXt         libX11.so, libSM.so, libICE.so
libxcb        libXau.so, libXdmcp.so
lcms2         libjpeg.so, libtiff.so
git           libpcre2-8.so
gdb           libexpat.so
newt          libslang.so, libpopt.so
libzip        libbz2.so
```

1,779 distinct dangling link names exist under `/opt/hud`, so **a correlation
this broad is not by itself evidence.** Almost any package would name one. The
distinction that matters is what the *error message* said.

**Strongly implicated — the error is "the library is there but unusable":**

| Package | Error | Reading |
|---|---|---|
| `freetype` | `libpng support requested but library not found` | configure found `libpng.pc`, could not use it |
| `libxslt` | `Could not find libxml2 anywhere` | `libxml2.so` present, target gone |
| `libvorbis` | `This usually means Ogg was incorrectly installed` | upstream's own words for a half-present Ogg |
| `ncurses` | `/dest/opt/hud/include/curses.h: No such file` | headers gone, links kept |
| `libXt`, `libxcb` | probe for a compiler/X feature fails oddly | X11 links dangle |

These should be **retried against a regenerated rootfs before any further
diagnosis**, and it would not be surprising if most of them simply build.

**Not implicated — the error is in the source, and was read:**

| Package | Error | Reading |
|---|---|---|
| `git` | `implicit declaration of function 'write_archive'` | GCC 15 defaults to C23; genuine |
| `cmake` | `NCURSES_BOOL` collides with `cm::enum_set::size_type` | genuine C++ overload collision |
| `gdb` | `all-gdb Error 2` | unread; retry before diagnosing |
| `vim` | `configure` spins at 99.6% CPU | a probe loop, not a missing library |

**The honest summary: the E4 failure taxonomy in `PROJECT-STATE.md` attributes a
class to "toolchain strictness" that was never separated from this defect.**
`git` and `cmake` are toolchain failures — their errors were read and are in the
source. The rest were not distinguished, and cannot be until the rootfs is
regenerated and they are retried.

---

## The regeneration works — 2026-09-07

`scripts/make-minimal-rootfs.sh` was run on bf-build. It builds the root by
installing the nine bootstrap packages onto the base system rather than by
deleting 236 packages out of a populated tree, and the difference is not
marginal:

```
                              current root      regenerated
packages registered           242               9
dangling symlinks             2226              0
escaped pip dist-info trees   66                0
base-system dist-info trees   11                11
```

The eleven that survive are the genuine base system — `cffi`, `cryptography`,
`flit_core`, `jinja2`, `markupsafe`, `meson`, `packaging`, `pip`, `pycparser`,
`setuptools`, `wheel` — and the removal was checked for collisions before it ran:
no top-level name belongs to both a kept and a removed distribution, so the
date-based split is safe rather than merely plausible.

The bootstrap floor works in the result:

```
curl : /usr/bin/curl
curl 8.15.0 (x86_64-pc-linux-gnu) libcurl/8.15.0 OpenSSL/3.5.2 zlib/1.3.1
  brotli/1.1.0 zstd/1.5.7 libidn2/2.3.8 libpsl/0.21.5 nghttp2/1.66.0
HTTP 200 47166B   from http://172.19.1.7/hud-unstable/packages.list
245 packages available (251 total versions)
```

All nine libraries are linked into the curl that the client depends on, which is
the thing the floor exists to guarantee.

**What still has to happen:** pack it, put it where the builder overlays, and
**retry the E4 failures against it**. The list to retry first is the one above —
`freetype`, `libxslt`, `libvorbis`, `ncurses`, `libXt`, `libxcb` — because each
failed with an error meaning "the library is there but unusable", which is
exactly what 2,226 dangling symlinks produce. Until that retry runs, the
connection between them is a well-supported hypothesis and not a demonstrated
cause.

Keep the current root until a batch has been rebuilt against the new one. It is
the only thing every result so far was produced against.

---

## A second class of defect the same sweep found: `Source:` naming the wrong project

Not a rootfs problem, recorded here because it was found the same way — by
running something and reading what it said rather than by inspecting a
definition that looked fine.

`openldap`'s `Source:` pointed at `db-5.3.28.tar.gz`, Berkeley DB, while its
`[configure]` passed openldap's own flags. `Source-SHA256` had been computed
over that wrong tarball, so verification passed. The build fetched Berkeley DB,
extracted it, and died with `./configure: No such file or directory`.

**The published openldap was therefore never built from its definition.** It was
built by hand, and nothing in the pipeline could have noticed.

Sweeping every definition for a `Source:` filename that does not resemble its
package name turns up eleven, and ten are legitimate:

| Package | Source file | Why it is fine |
|---|---|---|
| `brotli`, `libseat`, `ninja`, `tree`, `vim`, `yajl`, `python3-distlib` | `v1.1.0.tar.gz`, `0.9.1.tar.gz`, … | GitHub release tarballs, named for the tag |
| `java-bin` | `OpenJDK-24.0.2+12-x86_64-bin.tar.xz` | the package is a repackaged JDK |
| `libibverbs` | `rdma-core-53.0.tar.gz` | libibverbs is a component of rdma-core |
| `liburcu` | `userspace-rcu-0.14.1.tar.bz2` | upstream's own name |

`openldap` was the only real one. The sweep is worth re-running whenever
definitions are edited in bulk:

```bash
# a Source whose filename bears no resemblance to the package it claims to build
grep -H '^Source:' huddefs/*/*.huddef
```
