#!/bin/bash
# Give every package in unstable the definition it was actually built from.
#
# hud-repo-manager archives a .huddef into the pool only when it finds one
# beside the .hud being added. The driver ships the .hud alone, so the pool kept
# whatever the original seeding left — definitions dated May 11 sitting next to
# packages rebuilt in September, several of them v1 files describing a v2 build.
# CLAUDE.md makes the archived huddef the tiebreaker for which definition is
# real, so a stale one is actively misleading.
#
# hud-build stores the definition it used inside the package. This extracts that
# and attaches it with `add-def`, the manager's own sanctioned path, rather than
# writing into the pool directly.
set -uo pipefail
POOL=/var/www/hud-unstable/pool/main
WRAP=/var/hud-build/bin/hud-unstable
DRY="${DRY:-1}"

updated=0; same=0; noembed=0
for art in "$POOL"/*/*/*.hud; do
    [ -f "$art" ] || continue
    member=$(tar tf "$art" 2>/dev/null \
             | grep -m1 -E '^\./opt/hud/share/hud/info/[^/]+/[^/]+\.huddef$') || true
    [ -n "$member" ] || { noembed=$((noembed+1)); continue; }

    tmp=$(mktemp)
    tar xOf "$art" "$member" > "$tmp" 2>/dev/null || { rm -f "$tmp"; noembed=$((noembed+1)); continue; }
    name=$(sed -n 's/^Package:[[:space:]]*//p' "$tmp" | head -1)
    version=$(sed -n 's/^Version:[[:space:]]*//p' "$tmp" | head -1)
    [ -n "$name" ] && [ -n "$version" ] || { rm -f "$tmp"; noembed=$((noembed+1)); continue; }

    dest="$(dirname "$art")/${name}-${version}.huddef"
    if [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
        same=$((same+1)); rm -f "$tmp"; continue
    fi
    updated=$((updated+1))
    if [ "$DRY" = "1" ]; then
        echo "  would update  $name-$version"
    else
        "$WRAP" add-def "$name" "$version" "$tmp" >/dev/null 2>&1 \
            && echo "  updated  $name-$version" \
            || echo "  FAILED   $name-$version"
    fi
    rm -f "$tmp"
done
echo
echo "stale/missing: $updated   already correct: $same   no embedded definition: $noembed"
