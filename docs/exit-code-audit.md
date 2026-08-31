# Exit-code audit — `hud` and `hud-repo-manager`

Written 2026-09-01. **Nothing here is fixed.** This measures the size of the
problem so the fix can be a separate reviewable change. `hud-build` and
`hud-test` already work around the parts that affect the build pipeline.

## Why this audit exists

The same defect was found twice by accident, in ways that both produced a
confident green result from a step that had done nothing:

1. `hud-test` reported **"zlib passed"** for a package it never installed.
   `hud install -y /path/to/pkg.hud` printed `Package not found`, exited 0, and
   the checks that followed validated the copy of zlib that was already in the
   base rootfs.
2. `hud-build` reported **"Build deps installed"** after `hud install -y zlib`
   printed `Package not found: zlib`. The `|| die` guard never fired. libpng
   then built green against the base system's own zlib, with its declared
   dependency never actually installed.

Both are the same root cause. This audit checks whether it is systemic.
It is.

## Method

- **`hud`**: read statically, then confirmed empirically inside a
  `systemd-nspawn` container running the minimal rootfs, against both a working
  and a deliberately unreachable repository.
- **`hud-repo-manager`**: **read statically only.** `add` and `remove` mutate
  `/var/www/hud-repo/`, which is off-limits, so its behaviour below is derived
  from the source rather than observed.

Line numbers are for the copies running on bf-repo: `hud` v1.1.0 (1648 lines)
and `hud-repo-manager` v1.1.0 (710 lines), both now committed to git.

---

## `hud` — the client

**None of `install`, `update`, `remove` or `upgrade` contains a single
`return 1`.** Each function ends by falling off the end, so the exit status is
whatever the final `log_success` echo returned, which is always 0.

### Measured

| Command | Condition | Exit |
|---|---|---|
| `hud install -y no-such-package` | package does not exist | **0** |
| `hud install -y /path/to/file.hud` | local paths unsupported | **0** |
| `hud remove -y no-such-package` | not installed | **0** |
| `hud upgrade -y` | — | **0** |
| `hud autoremove -y` | — | **0** |
| `hud update` | **repository unreachable** | **0** |
| `hud install -y zlib` | after that failed update | **0** |
| `hud source no-such-package` | package does not exist | 1 ✅ |

`hud source` is the only one of the eight that reports failure.

### `cmd_update` (L512–582) — the most damaging

```bash
sqlite3 "$DB_FILE" "DELETE FROM available" 2>/dev/null || true     # L520
...
download_file "$index_url" "$list_file" "package list from $url" || continue   # L550
...
log_success "Updated $repo_count repositories"                     # L580
```

The `available` table is **wiped before** anything is fetched. A failed download
then `continue`s, and the function reports success. Measured against an
unreachable repo: `[✓] Updated 0 repositories`, `[✓] 0 packages available`,
exit 0, and the table left empty.

So a transient network failure silently converts the client into one that
believes **no packages exist at all** — and every subsequent `install` reports
`Package not found` and exits 0. That is the exact chain that produced the
silent Build-Depends failure.

### `cmd_install` (L587–863)

Six error paths that `continue` the loop and never affect the exit status:

| Line | Condition |
|---|---|
| L625 | `Version $requested_ver not found for $pkg` |
| L636 | `Package not found: $pkg` |
| L768 | `Package not found locally` |
| L778 | `Package archive not found` |
| L782 | **`Refusing to install unsafe package: $name`** |
| L799 | **`Failed to extract: $name`** |

L782 and L799 are the serious ones: a package rejected as unsafe, or one that
failed to unpack, are both indistinguishable from success to any caller. Seven
`|| true` guards elsewhere in the function.

There is also no local-file install at all — `install <pkg>[=ver]` only — so
`hud install ./foo.hud` is always `Package not found`, exit 0.

### `cmd_remove` (L868–939)

No error paths guarded; **ten** `|| true`. Removing a package that is not
installed succeeds. Whether the files actually went away is not checked.

### `cmd_upgrade` (L979–1034) / `cmd_autoremove` (L1073–1150)

No `return 1` anywhere. `cmd_autoremove` has a single `return 0`.

---

## `hud-repo-manager`

**Materially better.** `add` and `remove` guard their error paths with `exit 1`.

| Command | Verdict |
|---|---|
| `add` (L89–203) | **OK** — every failure path exits 1: missing file (L93), extract failure (L102), no metadata (L106), missing PACKAGE (L109), invalid metadata (L122). The `return 0` at L142 is the deliberate "user declined to replace an existing version" skip. |
| `remove` (L204–243) | **OK** — exits 1 on missing name (L207) and package not found (L219, L227). |
| `rebuild-db` (L469–528) | **Partial** — a failed row import logs a warning and increments `skipped` (L518), and the function returns 0. The count *is* printed in the summary, so it is visible, but no caller can detect it. |
| `update-index` (L379–402) | **Unguarded, and the most dangerous of the four.** |

### `cmd_update_index` — writes the file every client reads

```bash
cat > "$INDEX_FILE" << EOF                     # truncates packages.list
...
sqlite3 -separator '|' "$DB_FILE" "SELECT ..." >> "$INDEX_FILE"    # unchecked
pkg_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(DISTINCT name) FROM packages")
log_success "Index updated: $pkg_count packages ($ver_count versions)"
```

`packages.list` is **truncated first**, then appended to by an unchecked
`sqlite3`. If that query fails, the file is left containing only its three
header comment lines — a valid, empty index served over HTTP to every machine.

The success message cannot detect this: `pkg_count` is counted from the
**database**, not from the file just written. It will cheerfully report
`Index updated: 245 packages` while `packages.list` contains none.

Not observed — running it writes to `/var/www/hud-repo/`.

---

## Impact ranking

1. **`cmd_update_index`** — can publish an empty index to every client while
   reporting success. Blast radius is every machine.
2. **`cmd_update`** — destroys the local package list on any network blip, then
   reports success; makes every later `install` a silent no-op.
3. **`cmd_install` L782/L799** — an unsafe or corrupt package is silently
   skipped and reported as installed.
4. **`cmd_install` L625/L636** — a missing package or version is a silent no-op.
5. **`cmd_remove`** — removal is never verified.
6. **`rebuild-db`** — failures counted and printed, but not signalled.

## What already works around this

- `hud-build` verifies every `Build-Depends` has a `PACKAGE` file in the build
  root after installing, instead of trusting the exit code.
- `hud-test` compares the installed `Build-Date` against the package under test,
  and installs local files by unpacking rather than through the client.

Both are workarounds in the pipeline. Neither fixes the client, and neither
helps anything else that calls it.

## Shape of the fix, when it is made

Not applied here. Three changes would cover most of it:

1. Give `cmd_update` a failure counter; fetch into a temp table and only replace
   `available` once at least one repository succeeded. Return non-zero if none did.
2. Track failures in `cmd_install`/`cmd_remove` loops and return non-zero if any
   package was not installed or removed. Keep `continue` so one bad package does
   not abort a batch.
3. In `cmd_update_index`, write to a temporary file, check the `sqlite3` exit
   status, count the lines actually written, and only then move it into place.

Worth pairing with the `unstable`/`stable` split, since (1) and (3) are the two
that can reach client machines.
