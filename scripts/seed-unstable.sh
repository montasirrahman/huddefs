#!/bin/bash
# Seed /var/www/hud-unstable from the live repository. Idempotent; re-running
# refreshes the staging repo from stable without touching the live one.
#
# Reads /var/www/hud-repo. Never writes to it. See docs/staging-repo.md for why
# unstable is a complete superset of stable rather than an overlay, and why the
# pool is a real copy rather than symlinks.
set -euo pipefail

LIVE=/var/www/hud-repo
UNSTABLE=/var/www/hud-unstable

[ -d "$LIVE/pool/main" ]   || { echo "no live pool at $LIVE/pool/main" >&2; exit 2; }
[ -f "$LIVE/packages.db" ] || { echo "no live db at $LIVE/packages.db" >&2; exit 2; }

mkdir -p "$UNSTABLE/pool/main"

echo "==> copying pool"
# --no-preserve=mode so the staging copies are not accidentally read-only.
# -u skips files already present with the same timestamp, so a re-run copies
# nothing. bf-repo's disk is USB-attached and its failure mode is sustained
# write load; an idempotent script should not rewrite 1.3 GB to prove it.
cp -a -u --no-preserve=mode "$LIVE/pool/main/." "$UNSTABLE/pool/main/"

echo "==> verifying by sha256, not by size"
live_sha=$(cd "$LIVE/pool/main"     && find . -type f | sort | xargs sha256sum | sort)
unst_sha=$(cd "$UNSTABLE/pool/main" && find . -type f | sort | xargs sha256sum | sort)
if [ "$live_sha" != "$unst_sha" ]; then
    echo "seed-unstable: copied pool does not match the live pool" >&2
    exit 1
fi
echo "    $(printf '%s\n' "$live_sha" | wc -l) files byte-identical"

echo "==> seeding packages.db"
sqlite3 "$UNSTABLE/packages.db" "DELETE FROM packages;"
sqlite3 "$LIVE/packages.db" ".mode insert packages" \
    "SELECT id,name,version,architecture,section,depends,description,filename,
            size,installed_size,sha256,build_date,service,added_date
     FROM packages ORDER BY name,version;" \
  | sqlite3 "$UNSTABLE/packages.db"

echo "==> generating packages.list"
"$(dirname "$0")/hud-unstable" update-index

echo "==> done"
sqlite3 "$UNSTABLE/packages.db" \
    "SELECT count(*)||' rows, '||count(DISTINCT name)||' names' FROM packages;"
