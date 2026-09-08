#!/bin/bash
# G1 — rebuild every package from source, dependency-ordered, unattended.
#
# Runs on bf-build. This is the milestone the hard gate in PROJECT-STATE.md
# names first, and the whole point is that it is not allowed to pass easily:
#
#   * it builds against roots/minimal-clean — the root built by INSTALLING the
#     nine bootstrap packages, not the one made by deleting 236 out of a
#     populated tree. The old root has 2,226 dangling symlinks and claims 242
#     packages it does not have, so a rebuild against it proves nothing.
#
#   * it publishes each package to unstable as it goes, so the next package
#     resolves the one just built rather than the one from February.
#
#   * it refuses to record success for an archive holding only metadata. 68
#     packages have shipped empty in this repository's history and every one of
#     them built, tested and published green.
#
#   * it runs the emptiness sweep and the definition lint at the end and FAILS
#     on a hit. A rebuild that produces 250 archives and does not check what is
#     in them is not evidence.
#
# Resumable: the driver skips anything already published, so re-running
# continues rather than restarting.
set -uo pipefail

REPO="${REPO:-/root/github-repo/huddefs}"
ROOTFS="${ROOTFS:-/var/hud-build/base-rootfs-minimal-clean.tar.zst}"
ORDER="${ORDER:-/var/hud-build/g1/order.json}"
STATE="${STATE:-/var/hud-build/g1-state.json}"
LOG="${LOG:-/var/hud-build/g1/g1.log}"

export PATH="/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export GIT_AUTHOR_NAME=montasirrahman GIT_COMMITTER_NAME=montasirrahman
export GIT_AUTHOR_EMAIL=montasirrahmanbd@gmail.com GIT_COMMITTER_EMAIL=montasirrahmanbd@gmail.com
export HUD_BASE_ROOTFS="$ROOTFS"
export BUILD_TIMEOUT="${BUILD_TIMEOUT:-21600}"

mkdir -p "$(dirname "$ORDER")"
say() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | tee -a "$LOG"; }

[ -f "$ROOTFS" ] || { say "FATAL: no clean rootfs at $ROOTFS"; exit 2; }

say "=== G1: full rebuild against $(basename "$ROOTFS") ==="

# --- the order ---------------------------------------------------------------
# Regenerated per run rather than cached: definitions change, and a stale order
# would build something before the dependency it acquired yesterday.
cd "$REPO"
python3 scripts/build-order.py "$ORDER" | tee -a "$LOG"
cycles=$(python3 -c "import json;print(len(json.load(open('$ORDER'))['cycles']))")
if [ "$cycles" -ne 0 ]; then
    say "FATAL: $cycles packages are in a dependency cycle. G1 cannot be honest"
    say "about a from-scratch rebuild while any package cannot be reached."
    exit 1
fi

python3 -c "
import json
d=json.load(open('$ORDER'))
json.dump(d['order'], open('/var/hud-build/g1/batch.json','w'))
print(len(d['order']),'packages in dependency order')
" | tee -a "$LOG"

# --- the rebuild -------------------------------------------------------------
# E5_STATE, not STATE: the driver renamed the variable when a second queue
# started running beside the first. Passing the old name left G1 writing to
# e5-state.json — the file that already lists ~100 packages as published — so
# the driver would have skipped every one of them and G1 would have reported a
# full from-scratch rebuild after building almost nothing. A milestone that can
# pass without doing the work is worse than no milestone.
say "starting the rebuild; state in $STATE"
[ -s "$STATE" ] || echo '{"published": [], "failed": {}}' > "$STATE"
E5_STATE="$STATE" E5_RESULTS="/var/hud-build/g1/results.json" \
    python3 "$REPO/scripts/e5-driver.py" /var/hud-build/g1/batch.json 2>&1 | tee -a "$LOG"

# --- second pass: cmake against the system curl ------------------------------
# cmake bootstraps with --no-system-curl to break the cmake -> curl -> brotli
# cycle. Once curl exists, cmake should be rebuilt against it so its curl gets
# security updates with everything else. Doing this is the difference between a
# bootstrap and a distribution.
if grep -q '^\s*--no-system-curl' "$REPO/huddefs/cmake/cmake.huddef"; then
    say "second pass: rebuilding cmake against the system curl"
    sed -i 's|^\( *\)--no-system-curl.*$|\1--system-curl \\|' "$REPO/huddefs/cmake/cmake.huddef"
    if hud-build "$REPO/huddefs/cmake/cmake.huddef" >>"$LOG" 2>&1; then
        say "  cmake rebuilt against system curl"
        /var/hud-build/pub.sh cmake >>"$LOG" 2>&1 && say "  published"
        # Keep the edit: it is what built the cmake now in the repository.
        # Reverting it would leave the definition claiming --no-system-curl
        # while the shipped package links the system curl — the same
        # record-disagrees-with-artifact defect that lost 33 conversions.
        cd "$REPO" && git add -- huddefs/cmake/cmake.huddef && \
            git commit -q -m "cmake: link the system curl after the bootstrap pass" \
            && say "  definition committed"
    else
        say "  WARNING: cmake would not build against the system curl."
        say "  The bootstrap cmake stands. This is the trade documented in"
        say "  docs/build-order.md and it is now measured rather than assumed."
        # Only revert on failure: the shipped cmake is the bootstrap one.
        cd "$REPO" && git checkout -- huddefs/cmake/cmake.huddef
    fi
fi

# --- the gates ---------------------------------------------------------------
say "=== exit gates ==="
fail=0

say "-- every package has a payload --"
empty=$(python3 - <<'PY'
import os, tarfile
bad = []
for root, _, files in os.walk("/var/www/hud-unstable/pool/main"):
    for f in files:
        if not f.endswith(".hud"):
            continue
        p = os.path.join(root, f)
        try:
            with tarfile.open(p) as t:
                names = [m.name for m in t.getmembers() if m.isfile()]
        except Exception:
            bad.append(f + " (unreadable)"); continue
        if not [n for n in names
                if "/share/hud/info/" not in n and not n.endswith("/.owner")]:
            bad.append(f.rsplit("-", 2)[0])
print(len(bad))
for b in sorted(bad):
    print("   ", b)
PY
)
n=$(echo "$empty" | head -1)
echo "$empty" | tee -a "$LOG"
[ "$n" -eq 0 ] || { say "GATE FAILED: $n packages ship nothing"; fail=1; }

say "-- definitions obey the hard rules --"
if python3 scripts/lint-huddefs.py >>"$LOG" 2>&1; then
    say "   lint clean"
else
    say "GATE FAILED: lint found definitions violating CLAUDE.md's hard rules"
    fail=1
fi

say "-- every dependency in the index names a package the index has --"
# Not just "no capability strings": a name the index does not contain is
# equally unresolvable, and the client warns and installs anyway. The published
# networkmanager carries "ddbus" and "10gobject-introspection" from a botched
# sed in the original packaging, which is exactly the kind of thing a rebuild is
# supposed to remove.
# Run it, THEN test it. Written as a pipeline, the `if` tested the exit status
# of `tail`, which is zero whatever check-index found — so this gate reported
# success against an index that check-index was rejecting with status 1.
python3 "$REPO/scripts/check-index.py" 2>&1 | tee -a "$LOG"
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    say "   every dependency resolves"
else
    say "GATE FAILED: the index has dependencies nothing provides (see above)"
    fail=1
fi

say "-- everything built --"
python3 - "$STATE" "/var/hud-build/g1/batch.json" <<'PY' | tee -a "$LOG"
import json, sys
s = json.load(open(sys.argv[1]))
q = json.load(open(sys.argv[2]))
print(f"   {len(s['published'])} of {len(q)} published, {len(s['failed'])} failed")
for k, v in sorted(s["failed"].items()):
    print(f"     {k}: {v.get('stage')} — {str(v.get('note'))[:90]}")
PY
nf=$(python3 -c "import json;print(len(json.load(open('$STATE'))['failed']))")
[ "$nf" -eq 0 ] || { say "GATE FAILED: $nf packages did not build"; fail=1; }

if [ "$fail" -eq 0 ]; then
    say "=== G1 PASSED ==="
else
    say "=== G1 FAILED — see the gates above ==="
fi
exit "$fail"
