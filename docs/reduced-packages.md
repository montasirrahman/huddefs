# Reduced packages

Packages that now ship **less** than the copy in `pool/`, and why. Every entry
here is a deliberate divergence from what was published, recorded so the
difference is auditable rather than discovered later by someone wondering where
a binary went.

A package only belongs here if all of the following were true when it was
decided:

- the failing target is **not a library** and provides **no soname**
- **nothing in the repository declares a dependency on it**
- the main library or binary builds correctly

Anything failing those tests goes to `docs/needs-human.md` instead. A library, a
soname, or something another package's `Requires` names is never disabled.

---

## `cmake` 4.1.0 — `ccmake` disabled

**Removed:** `/opt/hud/bin/ccmake`, plus its manual page and the
`CCMAKE_COLORS` documentation.
**Still shipped:** `cmake`, `ctest`, `cpack`.

`ccmake` does not compile under GCC 15.2. ncurses defines `NCURSES_BOOL` as a
macro expanding to `unsigned char`; cmake's `cm::enum_set` uses `size_type`,
also `unsigned char`; once `curses.h` is included the two constructor signatures
become identical and the compiler rejects them. The `numeric_limits` and
`std_function.h` errors further down the log are the same macro pollution.

`ccmake` is an interactive ncurses front-end for editing a CMake cache by hand.
It provides no library, no soname and no pkg-config file, and no package in the
repository depends on it. A build server never runs it. The alternative was
carrying a local patch against upstream C++ for a binary nobody invokes.

Applied as `-DBUILD_CursesDialog=OFF`.

---

## `lcms2` 2.17 — `tificc` disabled

**Removed:** `/opt/hud/bin/tificc`.
**Still shipped:** `liblcms2.so.2` and the remaining tools.

`tificc` links against libtiff and fails to build under GCC 15.2 while the
library itself builds correctly. It is a command-line colour-profile converter
for TIFF files — not a library, no soname, and nothing in the repository depends
on it.

Applied as `--without-tiff`.

---

## Not reduced: fixed with a compiler flag instead

`git` 2.50.1 and `gdb` 16.3 both failed on implicit function declarations, which
GCC 15 treats as errors because it defaults to C23. Both were fixed with
`-std=gnu17` rather than by disabling anything, so **they ship exactly what the
pool copy ships**. Where a flag will do, a flag is the right answer: it is the
conventional fix across distributions and it changes nothing about the artifact.
