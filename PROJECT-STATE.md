# Project state

Living status file. Updated and pushed with every batch so a fresh session can
pick up where the last one stopped. If you are resuming, read this first, then
`CLAUDE.md`, then `docs/WORKFLOW.md`.

---

## Where things stand

**Current phase:** E4 — mechanical v1 -> v2 conversion of the 148 EASY packages,
in batches of 20, strictly sequential. **Batch 1 of 8 complete.**

**Resume point:** `/var/hud-build/convert-state.json` on bf-repo lists every
package already processed. `scripts/convert-easy.py` skips those, so re-running
the driver continues rather than restarting.

```bash
# on bf-repo
bash /var/hud-build/e4/driver.sh          # continues from convert-state.json
tail -f /var/hud-build/e4/driver.out
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

## Standing constraints

Never, regardless of progress:

- write under `/var/www/hud-repo/`
- run `hud-repo-manager add` or `remove`
- deploy anything to `/usr/local/bin`
- merge the three D8 branches

Publishing and deployment are manual, human-approved steps.
