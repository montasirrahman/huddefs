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
