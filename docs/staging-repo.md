# G3 — the staging repository at `/var/www/hud-unstable/`

Built 2026-09-07 on bf-repo. Nothing under `/var/www/hud-repo/` was written; the
live repository was read only, and its `packages.list` still carries its original
2026-02-19 timestamp.

---

## Why it exists

E5/E6 fix the 66 empty `python3-*` packages, and they cannot be fixed in
isolation. Every Python build backend — `hatchling`, `setuptools-scm`,
`pathspec`, `pluggy`, `editables`, `trove-classifiers`, `meson-python`,
`cython`, `pyproject-hooks`, `pyproject-metadata`, `hatch-vcs`,
`hatch-fancy-pypi-readme` — is itself one of the 66. `hud-build` resolves
`Build-Depends` by running `hud install` inside the build root, against whatever
repository that root's `sources.list` names. Rebuilding `python3-hatchling`
correctly therefore changes nothing for the next build unless the fixed package
is *published* somewhere the build root can reach.

Publishing to the live repository is forbidden — the client does not verify
SHA256, so a bad publish reaches every machine that runs `hud update`. So the
fixed packages need a repository that is real enough to install from and that
nothing in production points at.

---

## Shape

```
/var/www/hud-unstable/
├── packages.db                sqlite, same schema as the live repo
├── packages.list              generated index, 251 entries
└── pool/main/<letter>/<name>/ 251 .hud + 251 .huddef
```

Served at `http://172.19.1.7/hud-unstable/`.

**No nginx change was needed.** The existing `hud-repo.conf` sets `root
/var/www` with a `try_files` catch-all, so `/hud-unstable/` and everything under
it is already served. That is worth stating explicitly: nginx was not reloaded,
so no in-flight package download on bf-build could be interrupted.

---

## It is a complete superset of stable, not an overlay

This is the design decision in G3, and it was forced by the client.

The obvious arrangement is two entries in `sources.list` — stable for the 245
existing packages, unstable for the fixed ones — and let unstable win. **The
client cannot express that.** `hud update` loads every repository into one
`available` table keyed `UNIQUE(name, version, repo_url)`, so the same package
at the same version from two repositories produces **two rows**. Installation
then does:

```sql
SELECT version FROM available WHERE name='X' ORDER BY version DESC LIMIT 1
SELECT version, filename, size, repo_url FROM available
  WHERE name='X' AND version='<that>' LIMIT 1
```

The second query has **no `ORDER BY`**. Which of the two rows wins is rowid
order — that is, whichever repository appears first in `sources.list`. A fixed
`python3-hatchling` published to unstable at the same upstream version as the
broken one in stable would therefore lose, silently, and the build would install
the empty package exactly as before.

The alternatives were:

1. **Bump versions in unstable** so `ORDER BY version DESC` picks them. Rejected:
   `Version:` is defined as the unmodified upstream version, and the comparison
   is a lexicographic string sort, which orders `1.10.0` below `1.9.0`.
2. **Fix the client's query.** That is a fourth D8-class change to a client that
   may not be deployed, and it would not help until it *is* deployed.
3. **Make unstable complete.** One repository in `sources.list`, one row per
   package, no ambiguity to resolve.

(3) is what was built. Unstable was seeded with all 251 archives and all 251
database rows from the live repo, so a build root pointing at unstable alone can
resolve every `Build-Depends` that stable could. A fixed package replaces the
broken one *in place*, because there is only one copy for it to replace.

### The pool is a real copy, not symlinks

Symlinking unstable's pool at the live pool would have saved 1.3 GB and was
rejected. `hud-repo-manager add` copies the new `.hud` over the destination
path, and a fixed package has the *same* filename as the broken one it replaces.
`cp` follows symlinks, so that add would have written **through** the symlink
into `/var/www/hud-repo/pool/` and overwritten a live package. Same failure mode
as the `cp -al` hardlink farm that corrupted the golden rootfs in F5.

All 502 files were verified byte-identical to the live pool by sha256 after the
copy, not by size.

---

## Publishing to it

```bash
/var/hud-build/bin/hud-unstable add /path/to/foo-1.2.3-x86_64.hud
/var/hud-build/bin/hud-unstable update-index
```

`hud-repo-manager` reads `$HUD_REPO_DIR` and **defaults to
`/var/www/hud-repo`**, so one forgotten export publishes to production. The
`hud-unstable` wrapper removes that possibility: it sets the variable itself,
ignoring any value already in the environment, and refuses with exit 3 if
`/var/www/hud-unstable` resolves — through symlinks — to the live tree. Both
behaviours were tested rather than assumed.

It runs the **D8-fixed** `hud-repo-manager-unstable` from `/var/hud-build/bin/`.
Nothing was deployed to `/usr/local/bin`; the system's v1.1.0 is untouched, and
the D8 branches remain unmerged.

That fixed `update-index` is the reason this is safe to automate: the v1.1.0 one
truncates `packages.list` in place, appends from an unchecked query, and reports
success from a database count rather than from the file it just wrote — so a
failed query serves a valid, empty index. The fixed one builds a temp file,
checks the query, counts what was actually written, refuses a silent shrink
unless `HUD_FORCE_SHRINK=1`, and only then moves it into place.

---

## Build roots point here

`/var/hud-build/roots/minimal/etc/hud/sources.list` on bf-build names unstable
and nothing else:

```
hud http://172.19.1.7/hud-unstable unstable main
```

Stable is deliberately absent, for the reason above: two repositories carrying
the same version is the ambiguous case, and leaving stable in would reintroduce
it.

---

## What this does not do

- **It does not verify signatures or SHA256 on install.** Unstable has exactly
  the same weakness as stable; it is isolated, not secured. That is gate 3 of
  the hard gate and is untouched here.
- **It is not a promotion path.** Nothing copies from unstable to stable.
  Promotion stays a manual, human-approved step, as does signing.
