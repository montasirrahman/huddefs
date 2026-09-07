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
  /root/github-repo/huddefs/docs/needs-human.md  <- open decisions, three of them blocking
  /root/github-repo/huddefs/docs/rootfs-audit.md <- read before trusting any build result

You are on bf-repo. BUILDING RUNS ON bf-build over ssh — never on bf-repo, whose
USB-attached disk has failed three times under build load and lost a write.
bf-repo keeps the repo, nginx, publishing, and G4/G5 (it has the only /dev/kvm).

DONE: E4 (all 148 EASY converted), G3 (staging repo at /var/www/hud-unstable/),
E5/E6 (33 of 66), E7 (10 of 24), E8 (all four patches now in the repo), E9
(docbook fixed), G2 (capability graph), G4 (boot gate passes).

QUEUE, in order:
  1. THE ROOTFS — regenerated, now PROVE it. docs/rootfs-audit.md.
     The old root has 2,226 dangling symlinks and 242 registered packages where
     it should have nine. A clean one is BUILT and PACKED:
         bf-build:/var/hud-build/roots/minimal-clean          (9 pkgs, 0 debris)
         bf-build:/var/hud-build/base-rootfs-minimal-clean.tar.zst   (961 M)
     Next step is the experiment, not more building:
         ssh bf-build 'bash /root/github-repo/huddefs/scripts/retry-against-clean-root.sh'
     It builds freetype, libxslt, libvorbis, ncurses, libXt, libxcb, gdb and
     lcms2 against BOTH roots and prints a verdict per package. Until it runs,
     "the dangling symlinks caused those failures" is a hypothesis.
     Do NOT delete the old root until a batch has been rebuilt against the new
     one — it is what every result so far was produced against.
  2. The three blocking decisions in docs/needs-human.md:
     - flit_core, packaging, calver are not packaged; they block 33 of the 66
     - who owns files outside /opt/hud; blocks the other 10 of E7
     - the cmake -> curl -> brotli cycle; blocks a genuine G1
  3. Rebuild E8's four patched packages and E9's docbook, then E7's remaining 10
  4. G1  — full rebuild of all 245, dependency-ordered. scripts/build-order.py
           gives the order and names the cycle. THE milestone.
  5. Rebuild the capability graph after G1 and watch `hud-graph stats` reach
     zero empty packages and zero name-kind edges.
  6. G5  — integration gate: the VM starts libvirtd and boots a guest.
  7. docs/roadmap-to-appliance.md, then stop.

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
     add/remove against the live repo, deploy the hud client or hud-repo-manager
     to /usr/local/bin, merge the D8 branches, or touch signing keys

Publishing to /var/www/hud-unstable/ is fine. Push after every batch.
```

---

## The two mistakes that cost the most, and they are the same mistake

Both were found this session, both by checking the artifact instead of the
process, and both had produced green builds for days.

**A resume point that records intent.** `convert-state.json` said E4 was 148/148
while 18 definitions were still v1: it was written from the build result, not
from the commit, and that batch's commit was lost. The check that found it does
not consult the state file at all:

```bash
grep -L 'Source-SHA256:' huddefs/*/*.huddef
```

**A lookup that returns empty on failure.** `repo_names()` read a bf-repo-only
path and swallowed `OSError`, so on bf-build every declared dependency looked
absent and was dropped — 55 definitions, `curl` losing nghttp2, gnutls, brotli,
libssh2 and libpsl among them. It now raises. An empty index is not a value that
function may return.

The general form: **when a lookup can fail, decide whether empty is an answer or
an error, and if it is an error, throw.** Everything downstream of both defects
was green.

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
