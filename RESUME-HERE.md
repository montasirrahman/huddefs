# Resume here

Paste-ready handover for starting a fresh session. Read `PROJECT-STATE.md` next —
it is the full picture; this file only gets you moving.

---

## 1. After `ssh bf-repo`

```bash
cd /root/github-repo/huddefs && cat PROJECT-STATE.md
```

## 2. First prompt to give the session

```
Read these in order before doing anything:
  /root/github-repo/huddefs/PROJECT-STATE.md     <- start here, full status
  /root/github-repo/huddefs/CLAUDE.md            <- rules for editing definitions
  /root/github-repo/huddefs/docs/needs-human.md  <- open decisions
  /root/blackflag/CLAUDE.md                      <- infra: the two machines

You are running ON bf-repo (a VirtualBox guest), not a laptop.

STATE: E4 is 87/148 EASY packages converted. All work is committed and pushed.
The run is STOPPED after a third block-device I/O failure on bf-repo at
2026-09-03 11:51 (sector 322812928, DID_TIME_OUT, "potential data loss").
Do not restart it on bf-repo.

bf-build is now 4 cores, has overlayfs in its kernel (bf-repo does not), a disk
5x faster, zero I/O errors, and already holds a verified backup of all 251
shipped packages. The migration plan is in PROJECT-STATE.md.

DO NEXT:
1. Offline fsck on bf-repo before trusting it again.
2. Migrate the build workload to bf-build per the migration plan.
3. Resume the remaining 61 EASY packages there.

NEVER: write under /var/www/hud-repo/, run hud-repo-manager add/remove against
the live repo, deploy to /usr/local/bin, merge the D8 branches, touch signing
keys. Publishing to /var/www/hud-unstable/ is fine.

HALT AND ASK: fresh I/O errors within 15 minutes, /var above 120 G used, or a
decision with no precedent in PROJECT-STATE.md.
```

---

## 3. Where everything is

### In git (safe, off-machine)

| Path | What |
|---|---|
| `PROJECT-STATE.md` | **Read first.** Status, incidents, precedents, migration plan |
| `CLAUDE.md` | Rules for editing definitions, including all precedents |
| `RESUME-HERE.md` | This file |
| `huddefs/<pkg>/<pkg>.huddef` | 246 definitions, 73 converted to v2 so far |
| `attic/` | 176 never-published definitions, untouched |
| `docs/conversion-triage.md` | All 245 classified: EASY 148, PIP 72, SUSPECT-EMPTY 66, ABSOLUTE-PATH 24, PATCH 4, MULTI-SOURCE 2 |
| `docs/conversion-progress.md` | Per-batch results table |
| `docs/needs-human.md` | Open decisions |
| `docs/reduced-packages.md` | Packages now shipping less than the pool copy, and why |
| `docs/exit-code-audit.md` | The exit-0-on-failure defect, measured |
| `docs/duplicate-report.md` | The original 941-file analysis |
| `docs/source-hashes.md` | Source-SHA256 for all 245 |
| `scripts/` | All pipeline tooling |

### On bf-repo only (NOT in git)

| Path | What | Risk |
|---|---|---|
| `/var/hud-build/convert-state.json` | **Resume point** — which packages are done | **Only copy. Back this up.** |
| `/var/hud-build/cache/` | 361 source tarballs, 1.2 G | Re-downloadable |
| `/var/hud-build/output/` | Built `.hud` files | Rebuildable |
| `/var/hud-build/e4/` | Driver, supervisor, their logs | In git as `scripts/` |
| `/var/hud-build/*.tar.zst` | Base rootfs images, 1.1 G + 2.7 G | Regenerable |
| `/var/hud-build/dropped-deps.json` | Dropped dependencies and their verdicts | Only copy |

### Off-limits

| Path | Rule |
|---|---|
| `/var/www/hud-repo/` | **The live repo. Read-only. Never write.** |
| `/usr/local/bin/hud`, `hud-repo-manager` | Never deploy. Still the original v1.1.0 |
| `/var/www/hud-unstable/` | Staging repo — safe to publish to |
| `bf-build:/var/backup/bf-repo/` | Verified backup of all 251 packages |

---

## 4. Useful commands

```bash
e4-status          # health of the conversion, whichever unit is current
e4-status -f       # follow the live log
tail -f /var/hud-build/e4/supervisor.log
```

**Never hardcode a unit name.** It changes on every restart (`e4g`, `e4h`, `e4i`,
`e4s…`). Tailing a dead unit looks exactly like a stalled run — that has caused
confusion more than once.

### Starting the run again (once the storage question is settled)

```bash
systemd-run --unit=e4run --property=Type=simple /bin/bash /var/hud-build/e4/e4.sh
systemd-run --unit=e4-supervisor --property=Type=simple /bin/bash /var/hud-build/e4/supervisor.sh
```

Use the **default** `KillMode` (control-group). An earlier version used
`KillMode=process`, which left the Python child running after every
`systemctl stop` — at one point three builds ran concurrently and orphaned
containers blocked every subsequent build.

### Stopping it

```bash
systemctl stop e4-supervisor    # supervisor FIRST, or it restarts the run
systemctl stop e4run
```

---

## 5. The five things most worth knowing

1. **bf-repo's storage has failed three times** (2026-09-01 22:10 at ~143 GB,
   2026-09-02 00:02 at ~183 GB, 2026-09-03 11:51 at ~165 GB). The third lost a
   write. `df` inside the guest reports space that does not exist.
2. **`hud install` exits 0 when it fails** — seven of eight client commands do.
   Never trust its exit code; verify the package landed.
3. **Nine packages are always present** in the minimal rootfs (curl, openssl,
   zlib, zstd, brotli, nghttp2, libidn2, libpsl, libunistring), so a
   `Build-Depends` naming only those is never validated.
4. **v1 `Depends` were transcribed from the LFS/BLFS book**, optional entries
   included, in the book's naming. A dependency absent from `packages.list` is
   presumed invalid, not missing.
5. **A package that built in 2026-02 is not evidence it builds today.** GCC 15
   defaults to C23; `git`, `gdb`, `cmake` and `lcms2` all needed work.
