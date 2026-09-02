# Project state

Living status file. Updated and pushed with every batch so a fresh session can
pick up where the last one stopped. If you are resuming, read this first, then
`CLAUDE.md`, then `docs/WORKFLOW.md`.

---

## Where things stand

**Current phase:** E4 — mechanical v1 -> v2 conversion of the 148 EASY packages,
in batches of 20, strictly sequential. **Batch 2 of 7 complete.**

**Resume point:** `/var/hud-build/convert-state.json` on bf-repo lists every
package already processed. `scripts/convert-easy.py` skips those, so re-running
the driver continues rather than restarting.

The conversion runs as a **transient systemd unit** so it survives the session
that started it. Earlier runs were killed twice by session teardown mid-batch.

```bash
# on bf-repo
systemctl status e4-conversion
journalctl -u e4-conversion -f
systemd-run --unit=e4-conversion --property=KillMode=process \
    /bin/bash /var/hud-build/e4/e4.sh      # resumes from convert-state.json
```

Results land in `docs/conversion-progress.md`, one section per batch.

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

The root filesystem had been grown from ~94 G to 980 G with `resize2fs` earlier
the same day, on **thin-provisioned storage**.

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

**3. Toolchain strictness (deferred to a human).**
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

## bf-repo is a VirtualBox guest — its `df` cannot be trusted

**This is the single most important operational fact about the machine.**

bf-repo is a VirtualBox VM on a Windows laptop. Its VDI lives on drive **F:**,
declared as 1000 GB, but F: has never had anywhere near that free. The guest
believes it has a 980 GB filesystem. **Real host headroom is ~332 GB.**

The consequence: `df` inside the guest reports space that does not exist. It
showed **852 GB available while the block device was rejecting writes.** Two I/O
failures resulted:

```
2026-09-01 22:10   writes rejected at ~143 GB (logical block 34995203+)
2026-09-02 00:02   writes rejected at ~183 GB
```

Both remounted the root filesystem read-only via `errors=remount-ro`, aborting
the journal and failing every write including git. Recovered by offline fsck both
times; the repository was verified intact afterwards.

### What follows from this

**Never gate on free space.** A free-space floor is worthless when df lies in the
optimistic direction — it will report hundreds of gigabytes free right up to the
moment writes fail. The supervisor enforces a **ceiling on space used** instead:
halt if `/var` exceeds 120 GB, well under the ~332 GB of real headroom.

**The VDI never shrinks.** Deleting files inside the guest frees space in the
guest and returns none of it to the host. Every byte ever written to scratch is
permanently consumed host disk. Build and test roots are therefore deleted
immediately after each package rather than at the end of a batch — 3.3 GB each,
twice per package, is 132 GB across a batch of twenty if left to accumulate.

**Sustained throughput is 30–43 MB/s**, measured both before and after the
failures. That is why builds are disk-bound rather than CPU-bound, why extracting
a 3.3 GB rootfs takes 103 s, and why a small package costs ~300 s with the
compiler mostly idle. It is also the strongest argument for the
`CONFIG_OVERLAY_FS=y` rebuild, which removes the extract rather than speeding it
up — and for moving builds to bf-build, whose disk runs at 224 MB/s and whose
kernel already has overlayfs.

### Status

F: cleared to 332 GB free. A 20 GB direct-write test passes at 30.8 MB/s.
`journalctl -k` shows nothing newer than 00:02. Whether the fault is resolved or
dormant is still unknown, so the supervisor halts on any I/O error in the last
15 minutes rather than restarting through it.

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
