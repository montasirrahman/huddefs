# BlackFlag Linux — package definitions

This repository holds the `.huddef` files that build every package in
BlackFlag Linux, a Linux From Scratch derivative. Packages are built by
`hud-repo-manager` into `.hud` archives, served from a repo, and installed by
the `hud` client.

## Layout

```
huddefs/<package>/<package>.huddef    one canonical definition per package
huddefs/<package>/patches/*.patch     patches, applied with -Np1 in order
huddefs/<package>/files/*             config files shipped with the package
docs/huddef-v2-spec.md                the format specification
```

**One definition per package.** The version lives inside the file. Never create
`foo-1.2.3.huddef` alongside `foo-1.2.4.huddef`, and never create a directory
named `old/` or dated `14 Feb 2026`. Git holds the history. This repository
previously accumulated 941 files for 245 packages that way; do not restart it.

## Reading order

Before editing any `.huddef`, read `docs/huddef-v2-spec.md`. It defines every
header field and section, and explains which v1 patterns are forbidden.

## This is a production distribution — no package is skipped

**Every package must build, and every dependency it needs must exist and be
declared.** Not "most of them"; not "the ones that were easy". A package that is
skipped, or that builds because something was left lying around in the build
root, is a package that will fail on a machine that installs it.

That means:

- **Find the root cause.** A failure is not resolved by removing the thing that
  failed, by adding `|| true`, or by moving the package to a list of exceptions.
  Read the error, work out what is actually missing or wrong, and fix that.
- **Follow the dependency down.** If a package needs something that is not
  packaged, package it. `util-linux` needed `ncurses` declared; `qemu` needed
  `libX11` and then `libyaml`, the second because `dtc`'s own metadata was
  incomplete. The chain ends when everything it needs is present and declared,
  not when the build happens to go green.
- **A green build proves nothing on its own.** Check the artifact: it has a
  payload, its libraries resolve, its declared dependencies install.

Deferring a package to `docs/needs-human.md` is for a genuine design decision
that changes the distribution — not for a build that is merely hard.

## Hard rules

These are not style preferences. Violating them produces packages that are
silently wrong.

1. **No network access inside build sections.** No `wget`, no `curl`, no
   `pip install`, no `git clone`. The builder fetches `Source:` and verifies
   `Source-SHA256:`, then disables the network. Patches live in `patches/`.
   Build-time Python packages go in `Build-Depends:`.

2. **Never write `|| true` after `patch` or a download.** A patch that fails to
   apply must abort the build. Hiding it ships a binary that differs from what
   the definition describes. `|| true` is acceptable only on genuinely optional
   operations, with a comment explaining why.

3. **`Source-SHA256:` is mandatory** whenever `Source:` is a URL.

4. **`Build-Depends:` is for build tools. `Depends:` is for runtime.** Do not
   put `cmake`, `meson`, `ninja`, or `nasm` in `Depends:` — that installs the
   toolchain onto production machines. Prefer `Depends: auto` and let the
   builder detect runtime dependencies from ELF, pkg-config, and dist-info.

5. **`[postinst]` may not create untracked files.** Anything written outside
   `$DESTDIR` during install will not appear in `FILES` and will not be removed
   by `hud remove`. Symlinks, config files, and directories belong in
   `[install]` under `$DESTDIR`. Never overwrite an existing config file; ship
   a `.default` and copy it only if the target is absent.

6. **Never touch signing keys, `packages.list`, or anything under
   `/var/www/hud-repo/`.** Publishing is a separate, human-approved step.


## Precedent: a declared dependency the repository does not have is presumed invalid

v1's `Depends:` fields were transcribed from the LFS/BLFS book, **including
optional entries**, and using the book's names rather than this repository's.
19 of the 148 EASY packages name something `packages.list` does not contain.

**A declared dependency absent from `packages.list` is presumed invalid, not
presumed missing.** Resolve it:

1. **Maps to a real package under another name** — rewrite it.
   `glib2` → `glib`, `libx11` → `libX11`, `libxext` → `libXext`,
   `freetype2` → `freetype`.
2. **No repository package exists** — drop it, and log it to
   `/var/hud-build/dropped-deps.json`. Never drop silently.

The evidence for the rule: all 19 affected packages shipped successfully while
none of the named dependencies was ever installable, so none of them can have
been required to build.

### Verifying a library drop

Dropping a documentation builder or a test-suite server is unambiguous. Dropping
something that is a real library — `libpulse`, `libxcursor`, `libxkbcommon`,
`elogind` and similar — might instead mean the build now silently omits a
feature. That is the "builds but disables features" failure this repository's
`CLAUDE.md` warns about, and it is invisible in a green build.

So for those, compare `hud-scan-deps` output for the newly built package against
the `.hud` currently in `pool/`:

- **derived `Requires` unchanged** → the feature was never compiled in, the drop
  changed nothing, continue
- **`Requires` reduced** → the drop removed real functionality: **stop and
  report that package**

The comparison is recorded per package in `dropped-deps.json` alongside the drop.
Tool and base-system drops — `texlive`, `doxygen`, `apache`, `samba`, `glibc`,
`java`, `python`, `libuv` — never halt the run.


## Precedent: disabling an optional sub-target that will not compile

A toolchain-strictness failure confined to an optional sub-target may be resolved
by disabling that sub-target **without asking**, when all three hold:

- the failing target is **not a library** and provides **no soname**
- **nothing in the repository** declares a dependency on it
- the main library or binary **builds correctly**

Record the disabled target and the reason as a comment in the definition, and
list the package in `docs/reduced-packages.md`, so the divergence from the pool
copy is auditable rather than silent.

**Prefer a compiler flag over disabling a feature.** GCC 15 defaults to C23, so
implicit-declaration errors in older C are resolved with `-std=gnu17`. That is
the conventional fix across distributions, not a workaround, and it leaves the
package shipping exactly what it shipped before. `git` and `gdb` were fixed this
way; `cmake` and `lcms2` needed the sub-target route.

**Never disable a library, anything providing a soname, or anything another
package's `Requires` names.** Those still go to `docs/needs-human.md`.

## Working on a package

```bash
./scripts/build-one.sh huddefs/qemu/qemu.huddef     # build in a clean container
./scripts/test-one.sh  qemu                         # install on a fresh VM and smoke test
```

A change is done when both succeed. Do not report success on the basis of
reading the definition — run the build.

## When a build fails

Read the log and classify before editing:

- **Missing header or library** → add to `Build-Depends:`, do not add an
  `apt`/`pip` call
- **Patch no longer applies** → rebase the patch in `patches/`, keep it applying
  cleanly, never delete it to make the build pass
- **New compiler error in upstream code** → check whether upstream has a fix
  commit before writing your own
- **Configure flag removed upstream** → check upstream release notes, update the
  flag, note the change in the commit message

If three attempts do not produce a green build, stop and leave the branch with a
summary of what was tried and what the remaining error is. A half-fixed
definition that builds but disables features is worse than a failing build.

### A declared dependency can be present and still insufficient

Three separate failures on 2026-09-08 were packages whose dependency **was**
declared and **was** installed. A dependency graph catches none of these; only
building it and reading the error does.

- **A header's own includes.** `qemu` declared `sdl2` and failed on
  `/opt/hud/include/SDL2/SDL_syswm.h:68: fatal error: X11/Xlib.h`. Installing a
  package gives you its libraries, not the headers its headers include. The
  package that includes the header declares it: `qemu` needs `libX11`.
- **Installed is not on `PATH`.** `docbook-xsl` declared `libxml2` and its
  `[postinst]` still died with `xmlcatalog: command not found`. postinst runs in
  a non-login shell that never sources `/etc/profile.d/hud-env.sh`, so a
  `[postinst]` that calls anything from `/opt/hud/bin` must set its own `PATH`.
- **A package's own library.** `java-bin` was failed by `hud-test` over
  `libjvm.so`, which `java-bin` ships. `ldd` could not see it because
  `/opt/jdk/lib/server` is on no loader path. `hud-test` now separates
  self-shipped from genuinely absent.

### Check what `Source:` actually points at

`openldap`'s `Source:` named `db-5.3.28.tar.gz` — Berkeley DB — while its
`[configure]` passed openldap's own flags. `Source-SHA256` had been computed
over that wrong tarball, so verification passed and the build failed much later
with `./configure: No such file or directory`. **A hash proves the file is the
one that was hashed, not that it is the right file.** The published `openldap`
was therefore never built from its definition.

`scripts/verify-sources.py` checks every hash against the cache;
`scripts/lint-huddefs.py` enforces the rules above. Neither catches a correct
hash over the wrong project — only reading the filename does.

## Commit messages

```
qemu: bump to 10.0.4
qemu: rebase python-fixes patch for 10.0.4
python3-attrs: fix empty package, install was missing DESTDIR
```

One package per commit where possible. Say what changed and why, not what
command you ran.

## Known problems being worked on

Context for anyone touching these areas:

- Roughly sixty `python3-*` packages are ~750 bytes and contain no payload —
  their `[install]` sections are missing `--root=$DESTDIR`. `python3-distlib`
  is the correct reference.
- `Depends:` fields across the tree mix build and runtime dependencies and are
  incomplete. Many packages work only because the base LFS system supplies
  libraries that hud does not track.
- Packages install to `/opt/hud`, not the FHS paths, so several definitions
  hand-write compatibility symlinks into `/usr/bin`. An FHS migration is
  planned; do not add new symlink workarounds without flagging it.
