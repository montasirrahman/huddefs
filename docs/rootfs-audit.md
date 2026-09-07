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
