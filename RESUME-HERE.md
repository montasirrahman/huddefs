# Resume here

Paste-ready handover for a fresh session. Read `PROJECT-STATE.md` next — it is
the full picture; this file only gets you moving.

---

## The one thing to know first

**Building happens on bf-build, not bf-repo.**

bf-repo's VDI is on a USB-attached external disk whose link drops under sustained
write load. Three I/O failures resulted, the third losing a write. bf-build's VDI
is on the internal NVMe, has overlayfs in its kernel, and is ~20x faster.

```
                bf-repo                     bf-build
storage         USB external, 30-43 MB/s    internal NVMe, 224 MB/s
overlayfs       CONFIG_OVERLAY_FS unset     present
/dev/kvm        present                     absent
role            repo, nginx, publishing     ALL BUILDING
                G4/G5 (needs KVM)
per package     ~300 s                      ~15 s
```

You can work *from* bf-repo — editing, git, docs, analysis are all fine there.
Just never run `hud-build` or `hud-test` on it.

---

## First prompt to give the session

```
Read these in order before doing anything:
  /root/github-repo/huddefs/PROJECT-STATE.md     <- full status, incidents, precedents
  /root/github-repo/huddefs/CLAUDE.md            <- rules for editing definitions
  /root/github-repo/huddefs/docs/needs-human.md  <- open decisions
  /root/github-repo/huddefs/docs/migration-to-bf-build.md

You are on bf-repo. BUILDING RUNS ON bf-build over ssh — never on bf-repo, whose
USB-attached disk has failed three times under build load and lost a write.
bf-repo keeps the repo, nginx, publishing, and G4/G5 (it has the only /dev/kvm).

STATE: E4 is 144/148 EASY packages converted and is still running on bf-build.
Check it with:
  ssh bf-build 'PATH=/opt/hud/bin:/usr/local/bin:$PATH e4-status'

QUEUE, in order. Move between phases yourself; reorder if a dependency makes the
given order impossible, record why in PROJECT-STATE.md, and continue.
  1. Finish E4 (4 left)
  2. G3  — staging repo at /var/www/hud-unstable/ (skeleton exists, packages.db
           initialised, D8 update-index staged at
           /var/hud-build/bin/hud-repo-manager-unstable)
  3. E5/E6 — the 66 empty python3-* packages, in DEPENDENCY ORDER. They must come
           after G3: every Python build backend is itself one of the 66, and
           hud-build resolves Build-Depends from a repo, so the fixed ones have
           to be published somewhere first. Converter written:
           scripts/convert-python.py
  4. E7  — ABSOLUTE-PATH (24)
  5. E8  — PATCH (4). qemu's patch is guarded by || true and the shipped qemu is
           probably unpatched; verify the patch actually applies.
  6. E9  — MULTI-SOURCE. alsa done; docbook reads /var/hud-build/staging and
           cannot build clean — log to needs-human.md and skip.
  7. G1  — full rebuild of all 245 from scratch, dependency-ordered. THE milestone.
  8. G2  — capability graph in SQLite at /var/hud-build/graph.db, plus hud-graph
           with rdeps/deps/why/orphans/missing. Exact matches, never LIKE.
  9. G4  — boot gate: a VM from the minimal rootfs booting systemd as PID 1.
           MUST run on bf-repo (KVM). Test by log content with a hard timeout,
           never by exit code — a panic and a clean boot both leave qemu running.
 10. G5  — integration gate: the VM starts libvirtd and boots a guest through it.
 11. docs/roadmap-to-appliance.md, then stop.

SOLVE AND CONTINUE — do not stop for these:
  - bugs in your own scripts: fix, verify idempotent, continue, note it
  - changes to hud-build/hud-scan-deps/hud-test: authorised; show the diff,
    commit separately from package work
  - a package matching a precedent in PROJECT-STATE.md: apply it, log, continue
  - no precedent: log to docs/needs-human.md with a recommendation, skip, continue
  - three identical failures: stop, diagnose the pattern, fix once, resume

HALT AND ASK — only these:
  1. I/O errors in the last 15 minutes, or a filesystem remounting read-only
  2. /var above 120 G used on either machine
  3. anything that would write to /var/www/hud-repo/, run hud-repo-manager
     add/remove against the live repo, deploy the hud client or
     hud-repo-manager to /usr/local/bin, merge the D8 branches, or touch
     signing keys

Publishing to /var/www/hud-unstable/ is fine. Push after every batch.
```

---

## Where everything is

### In git — safe, off-machine, on BOTH hosts

`github.com/montasirrahman/huddefs`, cloned at `/root/github-repo/huddefs` on
bf-repo and bf-build.

| Path | What |
|---|---|
| `PROJECT-STATE.md` | **Read first.** Status, incidents, precedents, hard gate |
| `CLAUDE.md` | Rules for editing definitions |
| `RESUME-HERE.md` | This file |
| `huddefs/<pkg>/<pkg>.huddef` | 246 definitions |
| `attic/` | 176 never-published definitions, untouched |
| `docs/conversion-triage.md` | All 245 classified |
| `docs/conversion-progress.md` | Per-batch results |
| `docs/needs-human.md` | Open decisions |
| `docs/reduced-packages.md` | Packages shipping less than the pool copy |
| `docs/migration-to-bf-build.md` | Why and how building moved |
| `docs/exit-code-audit.md` | The exit-0-on-failure defect |
| `docs/source-hashes.md` | Source-SHA256 for all 245 |
| `scripts/` | All pipeline tooling |

### On bf-build only — NOT in git

| Path | Why it matters |
|---|---|
| `/var/hud-build/convert-state.json` | **The resume point.** Only copy |
| `/var/hud-build/dropped-deps.json` | Dropped deps and their verdicts |
| `/var/hud-build/cache/` | 362 source tarballs — no network needed |
| `/var/hud-build/roots/minimal/` | Pre-extracted tree the overlay mounts over |
| `/var/hud-build/e4/` | Driver, supervisor, logs |

### On bf-repo

| Path | Rule |
|---|---|
| `/var/www/hud-repo/` | **The live repo. Read-only. Never write.** |
| `/var/www/hud-unstable/` | Staging repo — safe to publish to |
| `/usr/local/bin/hud`, `hud-repo-manager` | Never deploy. Still original v1.1.0 |
| `bf-build:/var/backup/bf-repo/` | Verified backup of all 251 packages |

---

## Commands

```bash
ssh bf-build 'PATH=/opt/hud/bin:/usr/local/bin:$PATH e4-status'     # health
ssh bf-build 'PATH=/opt/hud/bin:/usr/local/bin:$PATH e4-status -f'  # follow
ssh bf-build 'tail -20 /var/hud-build/e4/supervisor.log'            # 10-min heartbeat
```

**Never hardcode a unit name** — it changes on every restart (`e4run`, `e4x`,
`e4fin`, `e4s…`). Tailing a dead unit looks exactly like a stalled run.

### Start / stop

```bash
ssh bf-build 'systemd-run --unit=e4go --property=Type=simple /bin/bash /var/hud-build/e4/e4.sh'
ssh bf-build 'systemd-run --unit=e4-supervisor --property=Type=simple /bin/bash /var/hud-build/e4/supervisor.sh'
```

```bash
ssh bf-build 'systemctl stop e4-supervisor'   # supervisor FIRST or it restarts the run
ssh bf-build 'systemctl stop e4go'
```

Use the **default** `KillMode`. `KillMode=process` leaves the Python child
running after a stop — that produced three concurrent builds and orphaned
containers that blocked every subsequent build.

---

## Ten things that cost time to learn

1. **bf-repo's disk is USB and fails under build load.** Three failures, one lost
   write. Build on bf-build.
2. **`hud install` exits 0 when it fails** — seven of eight client commands do.
   Never trust its exit code; verify the package landed.
3. **`git` lives only at `/opt/hud/bin/git`** on both machines, which is off
   systemd's default service PATH. That silently failed every automated commit
   for a whole batch. Always export PATH in a unit.
4. **Nine packages are always present** in the minimal rootfs (curl, openssl,
   zlib, zstd, brotli, nghttp2, libidn2, libpsl, libunistring), so a
   `Build-Depends` naming only those is never validated.
5. **v1 `Depends` were transcribed from the LFS/BLFS book**, optional entries
   included, in the book's naming. A dependency absent from `packages.list` is
   presumed invalid, not missing.
6. **A package that built in 2026-02 is not evidence it builds today.** GCC 15
   defaults to C23; `git`, `gdb`, `cmake` and `lcms2` all needed work.
7. **Build sections run under `set -u`.** v1 definitions append to variables the
   environment is assumed to hold (`ACLOCAL_PATH`, `CPPFLAGS`), which is fatal.
   The builder now supplies them.
8. **Test in a container before running against 148 packages.** Every
   self-inflicted failure here came from not doing that.
9. **Measure on an idle machine.** Concurrent builds inflated one timing 3x and
   produced a projection that was wrong by 30 hours.
10. **`systemctl list-units` prefixes a failed unit with `●`**, so
    `awk '{print $1}'` returns the bullet. Use `--plain`.
