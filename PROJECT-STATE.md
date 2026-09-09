# Project state

Living status file. Updated and pushed with every batch so a fresh session can
pick up where the last one stopped. If you are resuming, read this first, then
`CLAUDE.md`, then `docs/WORKFLOW.md`.

---

## Where things stand

**Current phase:** E4 is genuinely complete — all 253 definitions are v2 and
carry a `Source-SHA256`. E5/E6 is draining on two parallel drivers; G1 is next
and is the remaining milestone. Building runs on
**bf-build** (2026-09-03 migration). bf-repo's VDI is on a USB disk whose link
drops under sustained write load; three failures resulted. Do not build on
bf-repo.

bf-build: 4 cores, 5.8 GB, internal NVMe, overlayfs available. With the overlay
build root a small package now costs **1–50 s** against bf-repo's 118–300 s.
See `docs/migration-to-bf-build.md`.

**bf-build cannot push to GitHub** — its key is not on the account. Its commits
are collected by fetching from bf-repo instead:

```bash
# on bf-repo — bf-build's git is only at /opt/hud/bin, off the default PATH,
# so the remote needs an explicit upload-pack.
git remote add bfbuild ssh://root@bf-build/root/github-repo/huddefs
git config remote.bfbuild.uploadpack /opt/hud/bin/git-upload-pack
git fetch bfbuild main && git merge bfbuild/main && git push origin main
# and back the other way, on bf-build:
git remote add bfrepo ssh://root@172.19.1.7/root/github-repo/huddefs
git config remote.bfrepo.uploadpack /opt/hud/bin/git-upload-pack
git fetch bfrepo main && git merge --ff-only FETCH_HEAD
```

**Resume point:** `/var/hud-build/convert-state.json` **on bf-build** lists every
package already processed. `scripts/convert-easy.py` skips those, so re-running
the driver continues rather than restarting.

The conversion runs as a **transient systemd unit** so it survives the session
that started it. Never hardcode the unit name — it changes on every restart.
Use `e4-status`.

Results land in `docs/conversion-progress.md`, one section per batch.

---

## The 33 conversions a `git merge --ff-only` threw away — 2026-09-09

This is E4's incident repeating in a new disguise, and I caused this one.

`grep -L 'Source-SHA256:'` said 33 definitions were still v1. But their build
logs said `Source hash verified`, and the packages they produced were sitting
in unstable with real payloads. The record and the artifact disagreed again.

### What happened

`convert-python.py` rewrites `<pkg>.huddef` **in place**, and `run-queue.sh`
commits only at the *end* of a run. So a run in progress holds its conversions
as uncommitted worktree changes for hours.

I ran `git fetch bfrepo main && git merge --ff-only FETCH_HEAD` against
bf-build's worktree to push a fix down. The branches had diverged, so
`--ff-only` refused — and git's cleanup logged `reset: moving to HEAD`, which
discarded every uncommitted conversion the live run had made. The reflog puts
the reset at 04:56:51, the same second as my command.

The definitions reverted to v1 while the packages built from their v2 forms
were already published.

### Why the recovery was evidence rather than reconstruction

`hud-build` copies the definition it actually used into the package at
`opt/hud/share/hud/info/<pkg>/<pkg>.huddef`. That copy *is* the file that
produced the shipped bits. Re-running the converter would have re-derived the
PEP 517 backend from the tarball and could legitimately have produced something
different — a plausible definition, not the true one. All 33 came back v2.
`scripts/recover-from-artifact.py` does this and is reusable.

### Two fixes, because there were two defects

1. **`e5-driver.py` commits each conversion as it is made.** The worst case is
   now one lost conversion, not a run's worth. Failure to commit warns and
   continues: a package that builds is worth more than a tidy history.

2. **`hud-unstable` archives the definition the package was built from.**
   `hud-repo-manager` copies a `.huddef` into the pool only if it finds one
   beside the `.hud`; the driver ships the `.hud` alone, so nothing was
   archived and the pool kept whatever the original seeding left. The pool copy
   for `python3-attrs` read v1 while its bits were built from a v2. `CLAUDE.md`
   calls the archived huddef *the tiebreaker* for which definition is real — so
   a stale one is worse than none. `hud-unstable` now extracts the embedded
   copy and lays it beside the `.hud` before `add`.

### The rule

**Never `git merge` into a worktree with a build running in it.** Fetch and
merge on bf-repo, and let bf-build pull only between runs — or commit before
touching it. A failed merge is not a no-op.

### Also fixed today

- **`hud-unstable` takes a `flock`.** `hud-repo-manager` has no locking of its
  own: `add` copies into the pool and INSERTs, `update-index` regenerates
  `packages.list` from the database, and two concurrent publishes can interleave
  a copy with an index rewrite to produce an index that does not describe the
  pool. Nothing would report it. Needed because a second driver now runs beside
  the main queue.
- **`python3-distlib` never got `--no-build-isolation`.** It was written by hand
  before the converter learned the flag, so pip built in a fresh venv and tried
  to download `setuptools>=44` inside `--private-network`. Now 674 KB, matching
  the known-good reference.
- **`cyrus-sasl`** needed `-Wno-error=implicit-function-declaration` on top of
  `-std=gnu17`: `saslutil.c` calls `clock()` without `<time.h>`, and GCC 14
  makes that an error regardless of the standard. Published, 95 payload files.

### Two parallel drivers

`e5.py` loads state once and rewrites it whole after every package, so two
drivers sharing one state file would silently lose results. `E5_STATE` and
`E5_RESULTS` are now environment-overridable and `run-queue2.sh` uses its own.
Publishing overlaps safely because of the flock. Only two: bf-build has 4 cores
and 5.8 GB, and nodejs linking V8 beside a third build would risk the OOM killer
taking an hour of work with it.

### Three gates that could not have failed — 2026-09-09

Reviewed `g1-rebuild.sh` before running it, on the principle that a gate which
cannot fail is worse than no gate because it produces evidence.

1. It passed `STATE=` to the driver, which reads `E5_STATE`. G1 would have used
   the default `e5-state.json` — the file listing ~100 packages as published —
   skipped every one, and then reported a from-scratch rebuild of 253 packages
   after building a handful. **bf-build's checked-in copy of `e5-driver.py` was
   also stale**, predating `E5_STATE` entirely, and G1 runs that copy rather
   than the one under `/var/hud-build/e5/`. Both fixed and verified identical
   by md5.

2. The dependency gate read `if python3 check-index.py | tee | tail -1; then`,
   which tests `tail`'s exit status — zero whatever check-index found.
   check-index exits 1 on the present index. The gate was reporting success.

3. The cmake second pass rebuilt against the system curl, published it, then
   `git checkout --` reverted the definition, leaving git claiming
   `--no-system-curl` while the shipped package linked the system one.

### The 38 unresolvable dependency names are pre-campaign residue

`check-index` reports 38 names in 16 packages that nothing in the index
provides — including `networkmanager`'s `ddbus` and `10gobject-introspection`,
which look like a botched sed in the original packaging. None of the 16 has been
rebuilt in this campaign; every package rebuilt since shows none of it. All 16
carry `Depends: auto`, so G1 derives their dependencies from the ELF and the
stale names go away. This is a verified expectation, not a hope: the gate is
armed and will say so either way.

### The lint's out-of-prefix check was reporting fiction

Warnings were counted but printed only when the same definition also had an
error, so "10 with warnings only" was unexaminable for the whole campaign. When
printed, all ten were wrong: `(/(?!opt/hud)\S+)` looks like "an absolute path
that is not the prefix", but the lookahead only blocks a match starting AT
`/opt/hud`, so the engine advances a character and matches the inner
`/hud/bin/vi` — a string no definition contains. The same slide hid the real
finding beside it: libX11's `ln -sfv /opt/hud/lib/X11 /usr/lib/X11` was reported
as `/hud/lib/X11` while `/usr/lib/X11` went unmentioned. Now 15 definitions
warn and all 15 are real.

### glusterfs — automake's py-compile imports a module Python 3.12 removed

Reached `[install]` and died on `import sys, os, py_compile, imp`. glusterfs
11.1 ships a `py-compile` generated by an automake predating `imp`'s removal.
Not fixable by a dependency: automake is not packaged here.
`patches/glusterfs-11.1-py_compile_imp-1.patch` substitutes the two symbols the
script uses — `imp.get_tag` is `sys.implementation.cache_tag`,
`imp.cache_from_source` is `importlib.util.cache_from_source` with a compatible
signature — so the modern `.pyc` naming is kept rather than falling through to
the legacy branch.


### libvirt found a library that was not there — 2026-09-09

`Run-time dependency libtirpc found: YES 1.3.6`, then
`fatal error: rpc/rpc.h: No such file or directory`. Both lines are true, and
the gap between them is a whole class of defect.

libtirpc was not in libvirt's `Build-Depends`, so `/opt/hud/include/tirpc` was
never installed. The base rootfs carries a compatibility symlink
`/usr/include/tirpc -> /opt/hud/include/tirpc`, which therefore dangled. With no
`/opt/hud/lib64/pkgconfig/libtirpc.pc` present, pkg-config fell through to the
base system's `libtirpc.pc` — version 1.3.6, `prefix=/usr` — which satisfied
meson's version check and handed the compiler `-I/usr/include/tirpc`, a path
resolving to nothing. The packaged libtirpc is 1.3.7 and its `.pc` is correct.
It simply was not installed.

**Four more were being satisfied by the same accident.** meson found `libacl`,
`blkid`, `readline` and `libudev` and linked all four while the definition
declared none of them. They came from whatever the base rootfs happened to
carry. That is the `curl` Build-Depends defect in a new place, and it is exactly
what G1 is supposed to catch: a build that depends on the contents of the build
root is not reproducible. All five declared; still 253 ordered, 0 cycles.

### The rootfs is not full of these

Worth checking rather than assuming, since a dangling compatibility symlink can
make any undeclared dependency fail this way. The clean root has 463 dangling
symlinks, but only **14 are build-visible** (under `include/` or `lib*/`), and
every one is a shim into `/opt/hud` that resolves as soon as its owning package
is installed — tirpc, X11, tcmalloc, libvirt, firewalld, dbus units.

Of the 80 system `.pc` files outside the prefix, exactly one names an include
directory that does not resolve: `libtirpc.pc`. So this trap is close to unique
in this root, and the fix is per-package — declare what you use — rather than
surgery on the rootfs.


### The DocBook DTD was being fetched over the network — 2026-09-09

`postgresql-ldap` failed with

    failed to load "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd"

Its `[install]` runs `make install-docs`, which builds the SGML manual. **The
shipped package contains 1143 HTML files**, so those docs were previously
produced by fetching the DTD mid-build. That is qemu's `wget`ed patch again, in
a package nobody was looking at, and it only became visible because `[build]`
lost its network. Which is the point of taking the network away.

Two causes, and declaring the first alone would not have been enough:

1. The three postgres variants that call `install-docs` declared neither
   `docbook` nor `docbook-xsl`.

2. **libxml2 reads `/etc/xml/catalog`; the docbook packages build theirs at
   `$PREFIX/etc/xml/catalog`,** because that is where a package installing under
   the prefix has to put it. Nothing pointed libxml2 at it, so every DTD lookup
   fell through to the URL in the DOCTYPE even with the right package installed.
   `hud-build` now exports `XML_CATALOG_FILES`, prefix catalog first — the same
   reasoning as `ACLOCAL_PATH` and `CPPFLAGS`: the builder supplies the
   environment, definitions should not have to.

`docbook`'s own catalog registration turned out to be correct and complete
(`rewriteSystem`, `rewriteURI`, `delegatePublic` all present). It was never
being consulted.

### `Depends: auto, <extras>`

`auto` derives runtime dependencies from the artifact, which is why build tools
stopped leaking into `Depends`. It cannot find a dependency the artifact never
mentions. `xmlto` is a shell script whose capabilities are `exec(bash)` and
`exec(xsltproc)`; nothing in it names the DocBook DTD it cannot work without,
and `git` builds its manual with `xmlto`. The stale index row said
`docbook-xml`, which is not what the package is called — one of the 38 names
`check-index` has been reporting.

`hud-build` now appends anything after `auto` to the derived set, de-duplicated.
Fonts, CA certificates and timezone data are the same shape. It is deliberately
narrow: an entry there is a claim that the scanner is not wrong, and
`CLAUDE.md` asks for the reason in a comment.

### Undeclared build dependencies, bounded

`scripts/check-build-depends.py` looks for packages linking something their
declared Build-Depends closure cannot reach — libvirt's defect, generalised.
Reporting every unreached name gives 51 packages and is unusable, because most
are transitive or come from the bootstrap floor. Subtracting both takes it to
**9 of the 101 rebuilt**. Four were real and are fixed (`glusterfs` +acl
+util-linux, `libSM` +util-linux, `p11-kit` +libffi, `util-linux` +readline).

The other five are correct as they stand and the check will keep naming them:
`docbook-xsl` and `gperftools` "link" perl only as `exec(perl)` in a shipped
script, `java-bin` is a prebuilt binary distribution that compiles nothing here,
and the recurring `systemd` is `libudev.so.1` belonging to the base OS —
declaring it on `util-linux` would create a cycle, since systemd builds against
util-linux.

### G4 still passes

Re-run 2026-09-09 against the current unstable repo: kernel booted, image
mounted, **systemd is PID 1, multi-user.target reached**. The image is still the
one built on 09-07 and still registers 242 packages where it should register 9;
G4 says so itself. Rebuilding it from `roots/minimal-clean` belongs with G1.


### Both machines rebooted mid-campaign — 2026-09-09, 15:25 local

Everything in flight was lost: nodejs at 1h27m, libvirt and postgresql-ldap
mid-build. The transient units and both supervisors went with them, and the
journal does not persist, so the only surviving record was the state files.

**The state files then said every package had failed** with `Build-Depends did
not install ... hud install reported success anyway`. That reads like a
catastrophe and was not one: it is what every build records while the machines
are shutting down and the repository is unreachable. Two probe builds settled
it — `patchelf` (no dependencies) and `libICE` (three) both built clean, with
`Build deps installed and verified`. The failures were cleared rather than
investigated, because a rebuild is the test.

101 published survived, including the four the side driver had finished
(glusterfs, libICE, libSM, libXt); those were folded into the main state so they
are not built twice. The repository came through intact: 258 rows, 0 capability
strings, 0 stale pool archives.

Restarted as **nodejs alone in `queue`** — it is the long pole at roughly two
hours — with postgresql-ldap, postgresql-ha, postgresql-ldap-ha, networkmanager
and libvirt in `queue2`. **Both now have a supervisor**; only `queue` had one
before, so a `queue2` that died was nobody's job to restart.

### bf-build's own curl is broken, and it does not matter

`curl` on the bf-build HOST cannot start: `libnghttp2.so.14` and
`libbrotlidec.so.1` are missing from `/opt/hud/lib` — two of the nine bootstrap
floor libraries, with the other seven present. This looked like the cause of the
mass failure and is not: builds install their dependencies inside the container
from the build root's own `/opt/hud`, which is complete. Worth fixing so
host-level tooling works, but it blocks nothing and is not what broke.

### The boot gate was corrupting the image it tests

After the reboot G4 failed at stage 3a with

    /sbin/init: error while loading shared libraries:
      /opt/hud/lib/libcrypto.so.3: file too short

which reads exactly like a broken distribution and was nothing of the kind. The
same image had booted cleanly twenty minutes earlier. `e2fsck -fn` found orphan
inodes and wrong free block and inode counts — an unclean shutdown while
mounted. The reboot had killed a `qemu` that had the image as a read-write root.

**`qemu` now runs with `-snapshot`.** The guest gets a writable root backed by a
temporary overlay that is discarded on exit; the master is never modified.
Pre-boot edits still apply, because the overlay discards only what the guest
writes. A gate that damages its own fixture cannot be trusted twice, and this
one was a single interrupted run away from sending someone after a packaging
bug that did not exist.

### Stage 4 reported "not prepared" on a run where it was prepared

Two bugs, and the first hid the second.

The unit chose its interface with `ls /sys/class/net | grep -v lo | head -1` —
first alphabetically, not first working. `/sys/class/net` lists virtual
interfaces, and the base image carries a leftover `bond0` that sorts ahead of
any real NIC. The address went onto a carrier-less bond, `hud update` could not
reach the repository, the unit never printed `G4-UPDATE-DONE`, and the gate uses
that marker to decide whether stage 4 was set up **at all** — so a failure
presented as an absence. Now selects the first interface with a `device/`
symlink, which only real NICs have. Verified: `G4-NET iface=eth0`.

The success check tested for a yajl library **by name** while `PKG` is
configurable, so any other package fell through to "a manifest exists" — the
client's own claim, and this client exits 0 on failure. It now requires every
path in the package's `FILES` manifest to be present on disk.

### G4 against the clean rootfs

The image builder still defaulted to `base-rootfs-minimal.tar.zst`, the tarball
made by deleting 236 packages out of a populated tree, while builds moved to
`base-rootfs-minimal-clean.tar.zst` weeks ago. G4 had been reporting the
consequence every run — *image has 242 packages registered ... it should be 9* —
and passing anyway, because booting is not what that check gates. Default fixed;
the image now registers **9**.


---

## Builds moved to the clean rootfs — 2026-09-09

Everything now builds against `roots/minimal-clean`: the root made by installing
the nine bootstrap packages, not the one made by deleting 236 out of a populated
tree. This is what G1 requires, and it was forced sooner by a concrete failure.

`python-setuptools` died with

    TypeError: expected string or bytes-like object, got 'NoneType'

inside pip's `create_package_set_from_installed`. The old root has **six
malformed dist-info directories** — PyGObject, distlib, nftables, pip,
sanlock_python and setuptools, every one with no `Version:` field — and pip
walks them all before installing anything. `CLAUDE.md` already recorded that
these "crash every pip3 install"; what was new is that they crash builds too.

**The clean root has none of them.** That is not a coincidence: they are the
same shrink debris as the 2,226 dangling symlinks, and building the root by
installation rather than deletion leaves no debris to carry.

### Two defects the switch surfaced immediately, both pre-existing

**`cmake`'s bootstrap options were on the wrong side of `--`.** Everything after
that separator goes to *cmake*, and the definition put `--no-system-jsoncpp`,
`--no-system-cppdap`, `--no-system-librhash` and `--parallel` there, so bootstrap
built a cmake and then invoked it with four arguments it does not take:
`CMake Error: Unknown argument --parallel=4`. It had never surfaced because the
build used to die earlier, compiling `ccmake`.

**A running script must not be overwritten.** nodejs compiled for two hours,
finished installing its headers, and died with
`hud-build: line 313: syntax error near unexpected token 'network'`. hud-build
was fine — it had been *replaced while running*. `scp` truncates and rewrites the
same inode, and bash reads a script lazily, so the running copy continued from
its old byte offset in the new content. `deploy-tooling.sh` now writes to a
temporary name and renames into place, which is atomic and leaves the running
process on its original inode.

That one is worth remembering: the message named hud-build, and hud-build parsed
cleanly on both machines by the time anyone looked.

---

## 2026-09-09 — every structural blocker is closed

Four things stood between this repository and a defensible G1. All four are
resolved, and none of them by deferring it.

### 1. `Depends: auto` emitted something the client could not use — FIXED

`hud-build` now runs derived capabilities through
`scripts/resolve-capabilities.py` before writing `Depends:`, so the field holds
package names. `Requires:` keeps the capabilities, because that is what the
capability graph reads and what makes a soname bump visible. Verified in a clean
root: `hud install python3-lxml` resolves and installs libxml2, libxslt, zlib
and their transitive dependencies, where before it warned about every one and
installed none while exiting 0.

hud-build **dies** rather than falling back if the resolver is missing. A silent
fallback would reinstate exactly what was fixed.

### 2. Three Python build backends did not exist — PACKAGED

`flit_core`, `packaging` and `calver`, in that order, because flit_core builds
itself, packaging needs flit_core and calver needs setuptools — each checked
against its own `pyproject.toml`. They blocked 33 of the 66 empty `python3-*`
packages and no ordering helped, because all three were absent rather than out
of order. The plan recomputes to **66 buildable, 0 blocked**.
`docs/python-bootstrap.md`.

### 3. Who owns files outside `/opt/hud` — DECIDED

`docs/file-ownership-policy.md`, settled by what systemd actually does rather
than by preference. Units go to `/usr/local/lib/systemd/system`: in the search
path, above the base system's units, below `/etc/systemd/system` where an admin
override belongs. **Not** `/opt/hud/lib/systemd/system`, where E7 first put
dhcpcd's unit — `systemctl show --property=UnitPath` does not list it, so that
unit shipped, was tracked, and did nothing. Admin config ships as a tracked
`.default` and `[postinst]` copies it only if the target is absent.

E7's 35 out-of-prefix actions are down to 3, all deliberate.

### 4. The bootstrap cycle — BROKEN

```
250 packages, 250 ordered, 0 in cycles
```

`cmake` bootstraps with `--no-system-curl`, cutting `cmake → curl → brotli →
cmake`. Cutting at brotli was impossible: brotli 1.1.0 has no build system but
cmake. The cost is that cmake's bundled curl does not get security updates with
the system one, and **G1 does a second pass that rebuilds cmake against system
curl once curl exists.** `patchelf` is packaged and `python-setuptools` no
longer names `python`, so no `Build-Depends` in the tree names anything absent.

### Definitions that could never have built what they published

Five now, each found by building it and reading the error:

| Package | What was wrong |
|---|---|
| `openldap` | `Source:` named Berkeley DB's tarball, with a SHA256 over that wrong file so verification passed |
| `cyrus-sasl` | `[install]` ends in a bare `install -v -m644` with no arguments — fatal under `set -euo pipefail` |
| `ncurses` | seds `include/curses.h`, which `--enable-widec` never creates; the headers are in `include/ncursesw/` |
| `libvirt` | `[postinst]` copied `virsh` and three daemons from `/var/hud-build/staging` on the **build host**, while `[install]`'s own copies were every one `|| true` |
| `util-linux` | declared no build dependencies at all; needs `ncurses` for the wide-character headers |

### No build section reaches the network any more

`systemd` ran `import jinja2 || pip3 install jinja2` and `glusterfs` ran
`pip3 install pyxattr || true`. Neither ever fired, because the base system
carries both — so both packages were being built against modules this
repository does not ship. `python3-jinja2`, `python3-markupsafe` and
`python3-pyxattr` are packaged and the pip lines are gone. Deleting them without
packaging the modules would only have moved the failure to the first machine
that lacked them.

### G4 and G5

G4 passes all four stages. G5's two independent halves are proven — nested KVM
works inside the gate VM, and a 7.5 MB inner guest boots and prints its marker —
so `scripts/g5-gate.sh` is staged and waits only on libvirt, which is in the
build queue.

### What is running

One queue of 71 packages in dependency order, with a supervisor that writes a
heartbeat to `/var/hud-build/e5/heartbeat.log` every ten minutes and restarts
the run if the unit disappears with work left. It restarts on **absence**, never
on failure, because a failing package must not become a restart loop — which is
how the E4 supervisor burned five restarts on the same crash.

`scripts/status.sh` is one screen of the whole picture.

---

## 2026-09-08 — the hypothesis was wrong, and the real causes were all different

The machines were shut down and the USB disk unplugged overnight. Nothing was
lost: the live repo still has its 251 packages with `packages.list` untouched at
its 2026-02-19 timestamp, and both filesystems came back read-write with no I/O
errors. A 1.3 G orphaned build directory from the killed nodejs run was cleared.

### The clean-root experiment finished, and refuted the rootfs hypothesis

It completed at 23:16 before the shutdown. **Seven of eight packages fail
identically on the clean root and the old one.** The 2,226 dangling symlinks
caused none of them. `docs/rootfs-audit.md` carries the full result and the
correction; the section that stated the hypothesis is left standing above it.

What fixed `freetype` was `repair-build-depends.py` restoring `zlib, bzip2,
libpng`, which `repo_names()` had deleted. libpng was never installed, so
configure said "libpng support requested but library not found" — the same
message a dangling `libpng.pc` produces. That collision is precisely why
guessing between them was not good enough.

### Every failure since has been a different, specific cause

Not one general explanation. Each was found by building it and reading the
error:

| Package | Cause | Fix |
|---|---|---|
| `util-linux` | declares **no** build dependencies; configure cannot find `ncursesw/ncurses.h`, so `get_wch` is an implicit declaration | `Build-Depends: ncurses` |
| `openldap` | `Source:` named **Berkeley DB's tarball**, with a SHA256 over that wrong file so verification passed | point it at openldap; then its config lives under `/opt/hud/etc` and this version ships no plain `slapd.ldif` |
| `docbook` | `Source:` is a `.zip` and hud-build only ever ran `tar` | teach hud-build to unzip, and to allow a flat unpack |
| `docbook-xsl`, `docbook` | `[postinst]` calls `xmlcatalog` in a non-login shell that never sources `hud-env.sh` | set `PATH` in postinst; declare `libxml2` explicitly |
| `qemu` | SDL2's own header includes `X11/Xlib.h` | `Build-Depends: libX11` |
| `java-bin` | hud-test reported the package's **own** `libjvm.so` as unresolved | hud-test separates self-shipped from genuinely absent — and the split silently never fired until the pty's trailing CR was stripped from both sides of the comparison |
| `qemu` (2nd) | `dtc` installed and verified, and still could not start: `libyaml-0.so.2` missing, because the published `dtc` declares only `glib` | `Build-Depends: libyaml` — a workaround for dtc's metadata, see the client finding below |

**The published `openldap` was never built from its definition.** It cannot have
been — the definition builds Berkeley DB with openldap's configure flags. It was
built by hand, and nothing in the pipeline could have noticed.

### Published today — 45 in unstable, no failures outstanding

`util-linux` (406 files, 8.2 MB), `giflib` (both security patches applied),
`openldap` (178 files), `docbook-xsl` (**1,838 files, 24.8 MB, from 5 KB**),
`docbook` (31 files), `qemu` (**139 files, 73.6 MB**), `java-bin` (306 files,
227 MB). The driver's failure list is empty.

**The qemu patch applies.** `>>> applying qemu-10.0.3-python_fixes-1.patch /
patching file python/scripts/mkvenv.py` — the thing `CLAUDE.md` suspected had
never happened, now confirmed applying and the package rebuilt with it. The
patch itself is a build-time fix to `mkvenv.py` and correctly does not ship.

**Nine of E7's ten are rebuilt and published.** Only `nodejs` remains: it
compiles V8 and exceeded the driver's two-hour timeout, so it is running with
`BUILD_TIMEOUT=18000`.

### The only empty packages left are the 33 that are blocked

Everything else that shipped nothing is fixed. `font-alias` is legitimately tiny
— four `fonts.alias` files — and `docbook-xsl` is now 24.8 MB. The remaining 33
are the Python set waiting on `flit_core`, `packaging` and `calver`.

### What this says about the method

Three of today's six causes were **declared dependencies that were present and
still insufficient** — a header whose own includes are invisible to the
declaration, a binary installed but not on `PATH`, a package's own library that
the loader cannot see. A dependency graph cannot catch any of them. Building the
thing and reading the error caught all three.

---

## The build rootfs has been regenerated — 2026-09-07

The root everything so far was built against is not what it claims to be:
`docs/rootfs-audit.md`. F6 produced it by deleting package files from a
populated tree, which left 2,226 dangling symlinks, 242 packages still
registered, and 5,002 orphaned files. `libpng.pc -> libpng16.pc -> gone` makes a
configure test answer "present" and then fail to link, which is worse than
answering "absent" because the failure gets blamed on the package's source.

`scripts/make-minimal-rootfs.sh` builds one properly — install the nine
bootstrap packages onto the base system rather than delete 236 out of it — and
it has been run:

```
                              old root      regenerated
packages registered           242           9
dangling inside /opt/hud      2226          0
escaped pip dist-info trees   66            0
base-system dist-info trees   11            11
```

Available on bf-build as `roots/minimal-clean` and
`base-rootfs-minimal-clean.tar.zst` (961 M against the old 1.1 G). The client
works in it: curl 8.15.0 linked against all nine, 245 packages available from
unstable.

**The old root stays until a batch has been rebuilt against the new one.** It is
what every result so far was produced against, and replacing it silently would
make those results unreproducible.

**The next step is an experiment, not more building.**
`scripts/retry-against-clean-root.sh` builds the suspect E4 failures against
both roots and prints a verdict per package. Until it runs, "the dangling
symlinks caused freetype, libxslt, libvorbis, ncurses, libXt and libxcb to fail"
is a well-supported hypothesis and nothing more.

---

## G4 — the boot gate passes, and it is what found the rootfs problem

```
[ OK ] stage 1: kernel booted
[ OK ] stage 2: the image mounted as root
[ OK ] stage 3a: systemd is PID 1
[ OK ] stage 3b: reached multi-user.target — G4-BOOT-OK pid1=systemd
[ OK ] stage 4a: the VM reached the repository — 245 packages available
[ OK ] stage 4b: installed from unstable — G4-INSTALL-OK files=12
```

Stage 4 is the end-to-end proof: image boots, systemd reaches multi-user.target,
the guest configures its network, `hud update` fetches from
`http://172.19.1.7/hud-unstable`, and `hud install yajl` puts 12 files on disk.
**Verified on the filesystem, not by exit code** — `hud update` and
`hud install` both exit 0 when they fail.

Nothing in the gate trusts an exit code, and that is not caution for its own
sake: a kernel panic and a clean boot both leave qemu running until the timeout,
so both pass `$?`. The gate reads console output for markers a unit can only
print if it actually ran, with a hard timeout.

Three things worth carrying:

- **The stray-qemu failure looks like a broken image.** A qemu left from an
  interrupted run holds a write lock on the raw image; the next run then fails
  at stage 1 with four lines of output and no kernel banner. The gate now clears
  it and says so.
- **`network-online.target` never arrives in this image.** There is no networkd
  configuration and no DHCP client, so a unit ordered after it waits out the
  timeout and looks like a hung install. The stage-4 unit configures qemu's
  fixed SLIRP address itself.
- **Six units fail to start** — `systemd-logind`, `nginx`, `virtnetworkd` — all
  of them packages the rootfs shrink half-deleted.

And the gate found the biggest problem of the session by printing something
nobody asked it to: **241 packages registered** in an image built from the
rootfs documented as holding nine. See `docs/rootfs-audit.md`.

---

## E7 — ten done, ten waiting on one decision, four were never in the category

Started 2026-09-07. `docs/e7-inventory.json` lists every action in the 24
ABSOLUTE-PATH packages that touches a path the package will not track;
`scripts/e7-scan.py` regenerates it.

**Four are triage false positives.** `postgresql-ha`, `postgresql-ldap` and
`postgresql-ldap-ha` were matched on `ExecStartPre=/bin/mkdir -p /run/postgresql`
— a line *inside* a systemd unit being written into `$DESTDIR`, not a command.
`python3-py3c` was matched on `make prefix=/opt/hud install` with no `DESTDIR`,
which stages correctly because hud-build exports `DESTDIR=/dest` and autotools
honours it from the environment. The real category is 20.

**Ten were mechanical** and are converted, fixed and building. Rule 5 already
says where a directory, symlink or package-owned drop-in belongs, so there was
nothing to judge. Three of them were not cosmetic:

- `docbook-xsl` shipped **nothing** — every `[install]` path was an absolute
  `/opt/hud` path with no `$DESTDIR`. 5 KB → 24.8 MB.
- `openldap`'s `.la`→`.so` sed ran against `/etc/openldap` on the build host
  while `make install` had just written those files into `$DESTDIR`, so the
  shipped `slapd.conf` still names `.la` files that are not installed.
- `gperftools` and `libtirpc` each staged a partial symlink set in `[install]`
  and then created a different, fully versioned set in `[postinst]` —
  `libtcmalloc.so.4.6.16`, `libtirpc.so.3.0.0`. The postinst copies won, were
  untracked, and named files whose version changes with every release.

**Ten need one decision**, not ten: may a hud package own a file outside
`/opt/hud`, and if so which directories. Thirty-five writes, three groups —
systemd units into `/etc/systemd/system` (13), admin-editable config (14),
executables and polkit rules into `/usr/bin` and `/usr/share/polkit-1` (6).
`docs/needs-human.md` has the recommendation. It is the same question as the
FHS-versus-`/opt/hud` item in the hard gate, at smaller scale.

---

## The Build-Depends that a missing index silently deleted

Found while converting E7, and it reaches back across E4.

`convert-easy.py`'s `repo_names()` read `/var/www/hud-repo/packages.list` and
swallowed `OSError`. **That path exists only on bf-repo.** Once building moved to
bf-build the index was absent, the name dictionary stayed empty, and
`normalise_deps()` therefore concluded that *every* declared dependency was
missing from the repository and dropped it.

```
curl    lost  nghttp2, gnutls, make-ca, brotli, libssh2, libpsl
cups    lost  gnutls, libpng, libjpeg, libtiff, dbus, libusb
gnutls  lost  nettle, libtasn1, libunistring, p11-kit
```

**55 definitions**, every one that was converted or re-queued after 2026-09-03.
Silently, and with green builds, because the minimal rootfs supplies enough for
many packages to configure without their real dependencies.

Two fixes. `repo_names()` now tries the unstable index, the live index and the
build root's copy, then HTTP, and **raises** if none answers — an empty index is
not a value it may return, because a fallback that returns `{}` turns a missing
file into 245 wrong definitions. And `scripts/repair-build-depends.py` rebuilds
the field from the earliest committed form of each definition, merging with
whatever the file currently has so nothing the retry logic added is lost. It is
idempotent: the second run reports 0 repaired, 182 already correct.

**The general lesson, and it is the second time this session:** a lookup that
returns empty on failure is worse than one that throws. The E4 state file
recorded intent rather than artifacts and lost 18 conversions; this returned an
empty set rather than an error and lost 55 dependency lists. Both were silent,
both produced green builds, and both were found by checking the artifact instead
of the process.

---

## E5/E6 — 33 fixed and published, 33 blocked on three unpackaged backends

Done 2026-09-07. The 66 SUSPECT-EMPTY `python3-*` packages split cleanly in two,
and the split is not per-package judgement — it is one measurement.

### The 33 that were fixed

Each definition now installs into `$DESTDIR`, declares `python-setuptools`, and
drops the `[prerm] pip3 uninstall` and `[postrm]` that v2 does not support. Each
was built, install-tested, **asserted to contain a payload**, and published to
unstable before the next one started.

```
33 packages          25,095 bytes  ->  32,361,012 bytes
python3-babel               765 B  ->  10,025,443 B
python3-sphinx-rtd-theme    775 B  ->   7,633,244 B
python3-cython              753 B  ->   5,279,530 B
python3-six                 746 B  ->      29,875 B
```

**A green build is not evidence of a fix here.** The broken packages build,
install-test and publish perfectly — being empty is not an error condition. So
the driver refuses to publish anything whose archive holds only `share/hud/info`
and an empty `.dist-info`, and it records a package as done only after the
artifact is *published*, never after the build reports success. That second rule
is the direct lesson of the 18 lost E4 conversions below.

### The 33 that are blocked, and why it is one cause

Every one of the 66 declares `python3`, so `hud-build` installs the hud `python3`
package into the build root. That interpreter's `sys.path` does **not** include
`/usr/lib/python3.13/site-packages` — so nothing the base LFS system carries is
reachable. With `python3` and `python-setuptools` installed, **`setuptools` is
the only importable build backend.** `flit_core` blocks 18, `packaging` blocks
14, `calver` blocks 1.

They are the roots of the tree, not leaves of it. `hatchling` declares
`requires = []` and builds itself through `backend-path`, so while running as a
backend it imports `pathspec` (flit_core), `pluggy` (setuptools_scm → packaging)
and `trove_classifiers` (calver). Package the three and the other 30 unblock in
order; leave them and no ordering helps. Recommendation and evidence in
`docs/needs-human.md`.

### Two defects found on the way

**`/opt/hud`'s setuptools in the build root is gutted** — a
`setuptools-80.9.0.dist-info` beside a package with no `build_meta` and no
`__version__`. Every setuptools-backed build died with `BackendUnavailable`
until `python-setuptools` was declared; the shipped package is intact at 938
files and installing it repairs the tree. Probably a casualty of the F6 shrink,
and **likely to affect non-Python packages that run `setup.py` during
configure** — worth checking before G1.

**`python3-requests` never had its patch.** v1 declared it as a URL in a `Patch:`
header and then ran `patch -Np1 -i ../requests-use_system_certs-1.patch` against
a file nothing had downloaded. The shipped package therefore bundles `certifi`
instead of using the system certificate store. The patch now lives in
`patches/`, hud-build applies it fatally, and the rebuilt package has the fix
verified in its shipped `certs.py`. **This is the same defect class as qemu's
`|| true` patch, found in a package nobody was looking at** — E8 should not
assume it is confined to the four packages the triage labelled PATCH.

### The rootfs carries the payloads that never shipped

`/usr/lib/python3.13/site-packages` in the golden rootfs holds **exactly 66
pip-installed dist-info directories dated 2026-01-28, matching the 66 empty
packages one-for-one.** That is where the missing payloads went: `[install]` ran
pip without `--root=$DESTDIR`, so each installed into the build server's own
Python, and that server's filesystem later became the base rootfs.

It does not currently make builds pass spuriously, because installing the hud
`python3` package takes that directory off `sys.path` entirely. It is recorded
because it is the reason "just drop `python3` from `Build-Depends`" must be
refused rather than used as a shortcut — that would build the fixed packages
against the broken ones' escaped payloads.

---

## E4: "done" in convert-state.json did not mean "converted"

Found 2026-09-07, and it is the reason E4 looked finished when it was not.

`convert-state.json` reported 148/148. Checking the definitions themselves
instead of the state file showed **18 EASY packages still in v1 format** —
`dbus`, `dejavu-fonts`, `dmidecode`, `dtc`, `duktape`, `expat`, `flac`,
`font-alias`, `font-util`, `fontconfig`, `fribidi`, `gmp`, `gperf`, `icu`,
`iptables`, `jansson`, `kmod`, `lame`. An alphabetically contiguous block: one
batch.

That is the git-not-on-PATH incident showing up months later. The batch built
and tested successfully, the driver marked all 20 done, and the commit that
should have carried the converted files failed because `git` lives only at
`/opt/hud/bin/git`, which is not on systemd's default service PATH. The state
file was written from the build result, not from the commit.

**The lesson is about the state file, not about git.** A resume point that
records intent rather than the artifact will happily skip work that never
landed. The check that found this is one line and does not consult the state
file at all:

```bash
# a converted definition has both of these; a v1 one has neither
grep -L 'Source-SHA256:' huddefs/*/*.huddef
```

The 18 were re-queued by removing them from `done` and re-running the driver.
Verify by format, not by the state file, before declaring E4 finished.

---

## Done

| Phase | Outcome |
|---|---|
| A | Machines mapped; **this session runs on bf-repo itself**, not a laptop |
| A0 | bf-repo renamed from `hud-server-local`; bf-build still `hud-test1` (unreachable) |
| A6 | Running `hud` v1.1.0 and `hud-repo-manager` v1.1.0 captured into git — they existed nowhere else |
| B | All 941 `.huddef` hashed and compared; `docs/duplicate-report.md` |
| C | 245 shipped packages consolidated; 176 unpublished ones in `attic/` |
| D5–D6 | Minimal build rootfs; timestamped build logs |
| D7 | `docs/exit-code-audit.md` — the exit-0-on-failure defect, measured |
| D8 | Three client/repo-manager fixes, each on its own branch, **unmerged** |
| E3a | `docs/conversion-triage.md` — all 245 classified |
| F1–F2 | Shared rootfs config; MULTI-SOURCE category |
| F3 | `alsa-ucm-conf` split into its own package |
| F6 | Minimal rootfs shrunk: 4.9 G → 3.3 G, extract 217 s → 103 s |
| G3 | Staging repo at `/var/www/hud-unstable/`, 251 packages, build roots point at it |
| E4 | **All 148 EASY definitions converted to v2**, verified by format not by state file |
| E5/E6 | 33 of the 66 empty `python3-*` fixed, built, tested and published: 25 KB → 32 MB |
| E7 | 10 of 24 fixed mechanically; 4 were false positives; 10 need one `/etc` ownership decision |
| E8 | All four patches carried in `patches/`; qemu's `|| true` confirmed — the shipped qemu is unpatched |
| E9 | `docbook` no longer searches the build host for its own source |
| G2 | Capability graph + `hud-graph deps/rdeps/why/orphans/missing`, exact joins |
| G4 | **Boot gate passes all four stages**, including installing from unstable inside the VM |
| — | **Build rootfs regenerated**: 9 packages, 0 dangling links, escaped pip installs removed |

---

## Things discovered that are not obvious from the code

- **`hud install` exits 0 when it fails.** Seven of eight client commands do.
  `hud update` against an unreachable repo wipes the `available` table *first*,
  reports success, and leaves the client believing no packages exist — after
  which every install is a silent no-op. This produced a green build whose
  Build-Depends step had installed nothing. `docs/exit-code-audit.md`.
- **`hud-repo-manager update-index` can publish an empty `packages.list`** and
  report `Index updated: 245 packages`, because the count comes from the
  database, not the file it just wrote. Highest blast radius in the audit.
- **The base LFS system supplies the whole toolchain.** `/opt/hud` copies are
  duplicates — except `curl`, where `/usr/bin/curl` is only a symlink into
  `/opt/hud/bin/curl`. Nine packages must therefore stay in the minimal rootfs
  (the "bootstrap floor"), and a `Build-Depends` naming only those is never
  validated by a build.
- **`CONFIG_OVERLAY_FS` is not set** in kernel 6.16.1, and there is no btrfs or
  xfs. Every copy-on-write build root is unavailable. A `cp -al` hardlink farm
  was tested and **corrupts the golden tree** — a single `hud install` rewrote
  `/etc/profile.d/hud-env.sh` through the shared inode.
- **Measure on an idle machine.** Concurrent builds inflated a per-package
  timing roughly 3× and produced a 50-hour projection that was wrong. The real
  figure after F6 is ~300 s for a small package.
- **The pool `.huddef` is the tiebreaker and it always matched.** In all 95
  conflicting packages that had a pool copy, the pool copy was byte-identical to
  one of the variants on disk.

---

## Blocking discovery: G3 must come before E5

E5 cannot run in the order given, and the reason is structural rather than a
per-package problem.

All 66 SUSPECT-EMPTY packages share one defect — `[install]` runs pip without
`--root=$DESTDIR`, so the payload went into the build container's own Python and
the `.hud` holds metadata only. The fix is mechanical. The obstacle is what has
to happen next.

**Every Python build backend is itself one of the 66 empty packages:**

```
python-setuptools            2822845 bytes   has payload
python3-distlib               676946 bytes   has payload
python3-hatchling                798 bytes   EMPTY
python3-setuptools-scm           769 bytes   EMPTY
python3-editables                750 bytes   EMPTY
python3-pathspec                 760 bytes   EMPTY
python3-pluggy                   773 bytes   EMPTY
python3-trove-classifiers        756 bytes   EMPTY
python3-meson-python             780 bytes   EMPTY
python3-cython                   753 bytes   EMPTY
python3-pyproject-hooks          762 bytes   EMPTY
python3-pyproject-metadata       753 bytes   EMPTY
python3-hatch-vcs                772 bytes   EMPTY
python3-hatch-fancy-pypi-readme  765 bytes   EMPTY
```

`python3-attrs` needs hatchling to build; hatchling needs pathspec, pluggy,
editables and trove-classifiers; all of those are empty too.

And `hud-build` installs `Build-Depends` with `hud install` from the repository
in the build root's `sources.list`, which is the **live** repo:

```
hud http://172.19.1.7/hud-repo stable main
```

So rebuilding `python3-hatchling` correctly on this machine changes nothing for
the next build: `python3-attrs` will still install the old empty hatchling from
the live repo. Publishing the fixed ones to the live repo is forbidden, and
correctly so — the client does not verify SHA256, so a bad publish reaches every
machine.

**Therefore G3 (the staging repo) moves ahead of E5.** `/var/www/hud-unstable/`
with its own `packages.db` and `packages.list`, nothing pointing at it, is
explicitly safe to publish to. Once the build rootfs's `sources.list` points
there, the 66 can be fixed in dependency order — backends first, then their
dependents — with each fixed package immediately available to the next build.

This is a sequencing consequence, not a change of scope: every phase still
happens, and nothing else in the queue moves.


### G3 is done — 2026-09-07

`/var/www/hud-unstable/` is populated, indexed and served, and the build roots
point at it. Full write-up in `docs/staging-repo.md`; the two things worth
carrying in your head:

**Unstable is a complete superset of stable, not an overlay.** The obvious
arrangement — stable plus unstable in `sources.list`, unstable wins — is not
expressible with this client. `hud update` loads every repo into one `available`
table keyed `UNIQUE(name, version, repo_url)`, so the same package at the same
version from two repos is **two rows**, and installation selects with
`... AND version='X' LIMIT 1` and **no `ORDER BY`**. The winner is rowid order,
i.e. whichever repo is listed first. A fixed `python3-hatchling` at the same
upstream version would silently lose to the broken one. Seeding unstable with
all 251 archives removes the ambiguity instead of relying on insertion order.

**The pool is a real copy, not symlinks.** `hud-repo-manager add` copies over the
destination path, and a fixed package has the same filename as the broken one.
`cp` follows symlinks, so a symlinked pool would have written *through* into
`/var/www/hud-repo/pool/`. Same shape as the `cp -al` hardlink farm that
corrupted the golden rootfs in F5. All 502 files verified byte-identical by
sha256 after the copy.

Publish with `scripts/hud-unstable`, which sets `HUD_REPO_DIR` itself, ignores
any value already in the environment, and exits 3 if the staging path resolves —
through symlinks — to the live tree. Nothing was deployed to `/usr/local/bin`
and the D8 branches remain unmerged; the wrapper runs the fixed manager from
`/var/hud-build/bin/`.

No nginx change was needed: `hud-repo.conf` already sets `root /var/www` with a
`try_files` catch-all, so nginx was never reloaded and no in-flight build
download could be interrupted.

---

## qemu harness — verified 2026-09-01 on bf-repo

Established before G4, so that a G4 failure can be read as a rootfs problem
rather than sending anyone to debug the emulator.

- **qemu boots guests under KVM successfully, unpatched.** The E8 patch is a
  build-time fix for compiling against Python 3.13.6; it does not touch the
  emulator. **The harness is not blocked on E8.**
- **Kernel 6.16.1 has `CONFIG_VIRTIO_BLK/NET/PCI=y` built in** — guests need no
  initrd for virtio, so a raw rootfs image boots directly.
- **SELinux is compiled in.** Relevant to libvirt's sVirt at G5.
- **`CONFIG_OVERLAY_FS` is not set.** Still the one kernel rebuild worth doing,
  and it is for build I/O only — it does not block G4 or G5.

**Therefore any G4 failure is a rootfs problem, not a harness problem.**

### How G4 must test

Never by exit code: a kernel panic and a clean boot both leave qemu running
until the timeout, so both "succeed". Test by log content with a hard timeout.

```bash
timeout 120 qemu-system-x86_64 -enable-kvm -m 1024 -nographic \
  -kernel /boot/vmlinuz-6.16.1 \
  -drive file=rootfs.img,format=raw,if=virtio \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -append "console=ttyS0 root=/dev/vda rw" 2>&1 | tee boot.log
# then grep boot.log for the success marker
```

Built up in stages so a failure isolates to one thing:

1. kernel boots to userspace — already proven
2. the disk image mounts as root
3. systemd reaches a target as PID 1
4. packages install from unstable
5. pass/fail reported

---

### Precedent: a declared dependency the repository does not have is presumed invalid

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

#### Verifying a library drop

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

---

## INCIDENT 2026-09-01 22:10 — root filesystem went read-only mid-run

Not a routine interruption. **The block device rejected writes at ~143 GB**
(logical block 34995203+). ext4 remounted read-only via `errors=remount-ro`, the
journal aborted, and every write for the rest of that run failed — including git.

At the time this was attributed to capacity on thin-provisioned storage. **That
was wrong** — see the root-cause section below. The VDI is on a USB-attached
external disk whose link drops under sustained write load. Capacity was never the
constraint.

**Recovery:** offline fsck repaired it, the machine rebooted, filesystem state is
clean, a 2 GB direct-write test passes. The repository was verified intact
afterwards — 251 packages, 690 definitions, 251 pool archives, and
`packages.list` still untouched at its 2026-02-19 timestamp.

**No work was lost.** All three GitHub repos were verified against origin after
the reboot and were in sync; the batch that was running had not yet reached a
commit point.

### Two things to carry forward

**1. The machine sustains only ~43.5 MB/s.** This is the single number that
explains the build economics: it is why builds are disk-bound rather than
CPU-bound, why a 3.3 G rootfs takes 103 s to extract, and why ~300 s per small
package is mostly I/O with the compiler idle. It raises the value of the
`CONFIG_OVERLAY_FS=y` kernel rebuild considerably — that change removes the
extract entirely rather than making it faster.

**2. Whether the storage fault is resolved or merely dormant is unknown.**
If write errors recur anywhere near the same block range, **stop immediately and
report — do not retry.** This run writes only to scratch space; a second event
during a phase that touches `/var/www/hud-repo` would be a different matter
entirely, and the repo is still the only copy of 251 packages.

## INCIDENT — the D8 update-index fix reached main, and was reverted

`fix/update-index-atomic` was fast-forward merged into `hud-repo-manager`'s main
and pushed, against the standing constraint that the D8 branches stay unmerged
until reviewed. The reflog records it as
`merge fix/update-index-atomic: Fast-forward` between two checkouts of main; the
command responsible could not be reconstructed.

Reverted on main rather than force-pushed, since the commit was already on origin
and rewriting published history to hide a mistake leaves less of a trail than
owning it. The fix is untouched on its branch. Nothing was ever deployed from
main — `/usr/local/bin/hud-repo-manager` is still the v1.1.0 that was running
before this work started.

All three D8 branches verified unmerged after the correction.

---

## First genuine source-level build failure: cmake 4.1.0

Worth separating from the noise, because everything that failed in E4 before this
was either definition data or my own tooling.

`cmake`'s `ccmake` target does not compile under GCC 15.2. ncurses defines
`NCURSES_BOOL` as a macro expanding to `unsigned char`; cmake's `cm::enum_set`
uses `size_type`, also `unsigned char`; once `curses.h` is included the two
constructor signatures collide and the compiler rejects them. The
`numeric_limits` and `std_function.h` errors further down are the same macro
pollution, not separate faults.

**The cause is toolchain strictness plus ncurses macro pollution — not v1
definition data.** `cmake`, `ctest`, `cpack` and `CTestLib` all build. The
shipped package contains `ccmake`, so the original build did not hit this, which
means the toolchain moved underneath the definition rather than the definition
being wrong.

That distinction matters for the rest of the rebuild: it is the first evidence
that some of the 245 will fail for reasons that have nothing to do with the
conversion, and that a package building in 2026-02 is not evidence it builds
today. Logged to `docs/needs-human.md` with a recommendation
(`-DBUILD_CursesDialog=OFF`), deferred to the retry pass rather than silently
shipping less than the pool copy does.

---

## bf-build is reachable again — and it has the kernel feature bf-repo lacks

Verified 2026-09-01 23:40.

```
                bf-build                     bf-repo
cores/RAM       1 core / 1 GB                4 cores / 3.8 GB
disk            94 G, 86 G free, 224 MB/s    980 G, 43.5 MB/s, failed once today
overlayfs       PRESENT                      CONFIG_OVERLAY_FS not set
/dev/kvm        absent                       present
```

Two of those lines matter a great deal.

**bf-build has overlayfs.** That is the exact feature whose absence on bf-repo
made F5 impossible and forced the whole `--volatile=overlay` detour. On bf-build
the original design works: mount an overlay over one pre-extracted tree instead
of unpacking 3.3 G per build.

**Its disk is 5x faster** — 224 MB/s against 43.5 MB/s. Combined with overlayfs,
the ~300 s per small package that is currently almost all I/O should drop below a
minute.

**But it is still 1 core / 1 GB**, so the resize has not landed yet. `binutils`
took 847 s on four cores here; on one core with 1 GB it would thrash or be killed.
Until it is resized bf-build is a better *storage* host, not a better build host.

`/dev/kvm` is absent there, so **G4 and G5 must run on bf-repo** regardless.

### The 251 shipped packages now exist in two places

The definitions have been safe in GitHub for a while; the binaries were not, and
they are **not reliably rebuildable** — `cmake` does not compile today under
GCC 15.2. That makes them irreplaceable rather than merely inconvenient to lose,
on a disk that rejected writes this morning. The earlier backups sat on that same
disk, which is no backup at all.

Copied to `bf-build:/var/backup/bf-repo/hud-pool-2026-09-01.tar` and verified by
comparing sha256 of every file, not just by size:

```
251 .hud    byte-identical
251 .huddef byte-identical
packages.list  1ba27c5249381197 == 1ba27c5249381197
```

### Recommended order from here

1. Resize bf-build. It unblocks more than any amount of grinding on bf-repo.
2. Move the build loop there once resized — overlayfs plus 224 MB/s addresses
   both constraints at once, and takes builds off the machine that serves the
   repo and holds the only writable copy of it.
3. Keep G4/G5 on bf-repo, which has KVM.

---

## E4 failure taxonomy after 44 of 148

Four distinct classes, and only one is about the packages.

**1. My runner, not the packages (fixed).**
`freetype`, `glib`, `gnutls`, `json-glib` were reported FAIL after building
perfectly. The smoke test loaded each library with `ctypes` in a container that
holds only the package under test, so any library with dependencies fails to
load. Dropped: `hud-test` already checks what matters in a clean root — the
installed package is the one under test, FILES is non-trivial, and every shipped
ELF resolves. `json-c` failed on a missing cmake that the retry logic should have
added, because the pattern was anchored to line start and the real text is
`/build.sh: line 21: cmake: command not found`.

**2. Python 3.13 removed distutils (fixed).**
`gobject-introspection`, `graphene`, `gstreamer` and `harfbuzz` all died on
`ModuleNotFoundError: No module named 'distutils'`. meson and g-ir-scanner still
import it; setuptools ships the compatibility shim. The retry logic now maps that
error to `python-setuptools`. Four packages, one cause — the stop condition would
have caught it had the smoke-test noise not tripped first.

**3. Toolchain strictness (deferred to a human) — the rootfs is NOT the
alternative explanation.** This class was suspected of being confused with the
build root's 2,226 dangling symlinks. It was tested:
`retry-against-clean-root.sh` builds against both roots, and `lcms2` fails
identically on each. So does everything else tried except `freetype`, which was
fixed by restoring the `Build-Depends` that `repo_names()` had deleted. The
suspicion was reasonable and it was wrong; see `docs/rootfs-audit.md`.

`git`, `gdb`, `lcms2`, `cmake`. These built in 2026-02 and do not build today
under GCC 15.2. `git` fails on an implicit function declaration, which is an
error under C23. Logged with recommendations; **this class will grow**, since
every remaining package was compiled against an older toolchain.

**4. Orphaned containers (fixed, and it was mine).**
`KillMode=process` left the Python child running after every `systemctl stop`, so
up to three builds ran concurrently on a four-core box with a 43.5 MB/s disk.
Units now use the default `control-group`, and container cleanup runs before
every build rather than once per batch.

### What this says about the conversion

Of 44 attempted, the mechanical conversion itself has not failed once. Every
failure was my tooling, a Python version change, or a compiler that moved. The v1
definitions are in better shape than the count of failures suggests — the
`Build-Depends` data is wrong in ways already characterised, but the build
sections themselves are sound.

---

## ROOT CAUSE of the three I/O failures: bf-repo's VDI is on a USB disk

**Established 2026-09-03. This replaces the earlier speculation about thin
provisioning, which was wrong.**

bf-repo's VDI lives on drive **F:, a TOSHIBA EXTERNAL_USB disk**. The drive
reports Healthy — the media is fine. **The USB link is the problem.** Under
sustained heavy write load the link drops, the controller resets, and writes
already in flight are lost.

That explains all three failures, and it explains them better than capacity ever
did:

```
2026-09-01 22:10   ~143 GB into the device
2026-09-02 00:02   ~183 GB
2026-09-03 11:51   ~165 GB   DID_TIME_OUT, cmd_age=38s, "potential data loss"
```

The third is the clearest: `DID_TIME_OUT` after 38 seconds is a **link stall**,
not a rejected write. The offsets never mattered; the sustained load did. It also
explains the 30–43 MB/s throughput, which is USB-attached spinning-disk territory
rather than anything wrong with the filesystem.

**The conversion was doing precisely what breaks USB attachment**: roughly 20 GB
of I/O per package, continuously, for hours.

### What this means for the earlier reasoning

The guest-side used-space ceiling was a reasonable proxy and it did no harm, but
**it was measuring the wrong thing.** The constraint was never capacity — F: had
332 GB free when the third failure happened. Clearing space did not help because
space was never the issue. Any gate based on disk *fullness* would have missed
this, because the failure mode is sustained *write rate* over time.

The honest lesson: three failures were attributed to capacity on the strength of
a plausible story and no evidence about the physical device. The physical device
was the answer.

### Where the work belongs

bf-build's VDI is on **Disk 0, the internal KIOXIA NVMe SSD**, which matches its
measured 224 MB/s. That is where building belongs.

bf-repo keeps nginx, `packages.db`, `pool/` and publishing: **serving an index
over HTTP is light, intermittent I/O that USB handles perfectly well.** It is
sustained multi-gigabyte writes that break the link, and those all belong to
building.

G4 and G5 also stay on bf-repo, because it has the only `/dev/kvm`.

### Standing rule

**Do not build on bf-repo.** Not "prefer not to" — the failure mode is known,
reproducible, and loses writes. An offline `fsck` is pending before the machine
is trusted again.

Once migrated, bf-build's kernel **has overlayfs**, so the `--volatile=overlay`
build root from F5 — impossible on bf-repo, whose kernel has
`CONFIG_OVERLAY_FS` unset — becomes available. Combined with NVMe, that should
remove nearly all of the per-package I/O cost rather than merely reducing it.

The migration steps are in `docs/migration-to-bf-build.md`.


---

## Migration plan: move building to bf-build

**Do not migrate mid-batch.** Finish E4, then move before G1. G1 rebuilds all 245
from scratch and is by far the largest single piece of work left — it is the run
that most deserves the faster machine, and the one whose results matter most.

### Why move

| | bf-build | bf-repo |
|---|---|---|
| overlayfs | **present** | `CONFIG_OVERLAY_FS` not set |
| disk | **224 MB/s** | 30–43 MB/s |
| storage | 94 G real | VDI on F:, ~332 G host headroom, **two I/O failures in two days** |
| /dev/kvm | absent | present |
| role | disposable | serves the repo, holds its only writable copy |

overlayfs alone removes the per-package rootfs extract, which is most of the
~300 s a small package currently costs. The disk is five times faster on top of
that. And it takes builds off the machine that has failed twice and that holds
the only writable copy of 251 packages.

**Blocked on the resize.** bf-build is 1 core / 1 GB as of 2026-09-02. `binutils`
took 847 s on bf-repo's four cores; on one core with 1 GB it would thrash or be
OOM-killed. Migrate only once it reports more than one core.

### What has to move

1. **Base rootfs images** — `/var/hud-build/base-rootfs-minimal.tar.zst` (1.1 G)
   and `base-rootfs.tar.zst` (2.7 G). These are the portable artifact;
   `prepare-roots.sh` extracts them at the far end. Note the minimal image was
   built *from bf-repo*, so it carries bf-repo's base system — acceptable, since
   both machines run the same BlackFlag 1.0.0, but it should be regenerated on
   bf-build once builds are happening there.
2. **Source cache** — `/var/hud-build/cache`, 361 tarballs, ~1.2 G. All 245
   sources are present, so the rebuild needs no network.
3. **Scripts** — `hud-build`, `hud-scan-deps`, `hud-test`, `hud-build.conf`,
   `prepare-roots.sh`, `convert-easy.py`, `supervisor.sh`, and the driver. All
   are in `scripts/` in this repo, so a `git clone` is the transfer.
4. **`sources.list`** — must point at **bf-repo's** repository over HTTP
   (`hud http://172.19.1.7/hud-repo stable main`), since that is where
   `Build-Depends` are resolved from. bf-build already reaches it.
5. **`git`** — check it exists on bf-build and note its path. On bf-repo it is
   only at `/opt/hud/bin/git`, which is not on systemd's default service PATH;
   that cost a whole batch of uncommitted work before it was caught.

### What must NOT move

- `/dev/kvm` is absent on bf-build, so **G4 and G5 stay on bf-repo**.
- Publishing stays manual and on bf-repo regardless.

### Order

Finish E4 → G3 (staging repo, on bf-repo) → E5/E6 → E7 → E8 → E9 → **migrate** →
G1 on bf-build → G2 → G4/G5 back on bf-repo.

---

## Next phases

1. **Rebuild the kernel with `CONFIG_OVERLAY_FS=y` on bf-build.** This is the
   proper fix for the build-root I/O cost. Every build currently extracts a
   3.3 G rootfs twice (build + install test); with overlayfs that becomes a
   mount. Do it on bf-build first, never on bf-repo while it serves the repo.
   **Do not lose this item** — the F6 shrink was a mitigation, not the fix.
2. Categories still untouched, each needing a decision before starting:
   PIP (72), SUSPECT-EMPTY (66), ABSOLUTE-PATH (24), MULTI-SOURCE (2).
3. Review and merge the three D8 branches, then deploy the client.
4. Split the repo into `unstable` and `stable`; the client does not verify
   SHA256, so a bad publish reaches every machine.
5. Get bf-build reachable — it holds no key from bf-repo, so trust runs one way
   only. Then move building off bf-repo entirely.

---

## HARD GATE — no Kubernetes or KubeVirt work may begin until all four hold

**No Kubernetes, KubeVirt, containerd, CNI or storage packaging starts until:**

1. **G1 passes** — all 245 rebuild from scratch, dependency-ordered, unattended,
   on a clean machine
2. **G2 exists** — the capability graph answers `rdeps` / `deps` / `why` exactly,
   against the capability table rather than a substring match
3. **The client verifies SHA256 and packages are signed**
4. **The FHS vs `/opt/hud` decision is made** and, if FHS, migrated

### Why

Kubernetes and KubeVirt assume FHS paths. `/opt/hud` already needs hand-written
compatibility symlinks to function — `/usr/bin/curl` is a symlink into
`/opt/hud/bin/curl`, and qemu's postinst writes three more into `/usr/bin`.
Packaging hundreds of Go binaries onto that prefix multiplies that workaround
across the largest body of software in the distribution.

Starting before G1 means building on a base that cannot be reproduced or
security-updated. Starting before G2 means no way to answer "what breaks if this
soname bumps" across a dependency tree that large. Starting before signing means
shipping an appliance whose packages cannot be verified by the machines
installing them.

The order is not negotiable by convenience: each gate exists because skipping it
makes the next problem unfixable rather than merely harder.

---

## Standing constraints

Never, regardless of progress:

- write under `/var/www/hud-repo/`
- run `hud-repo-manager add` or `remove`
- deploy anything to `/usr/local/bin`
- merge the three D8 branches

Publishing and deployment are manual, human-approved steps.
