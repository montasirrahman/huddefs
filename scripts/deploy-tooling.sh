#!/bin/bash
# Sync the build tooling from this checkout to where the builder actually runs
# it, and verify byte-for-byte afterwards.
#
# This exists because "the fix was not deployed" has been a real failure twice.
# convert-easy.py's crash fix sat in git while bf-build ran the old copy, and
# hud-scan-deps' optional-extras fix was committed and pushed while every build
# kept emitting python3dist(anthropic) — the code was right and the machine
# running it was not.
#
# Run from bf-repo. Refuses to deploy anything the checkout does not have, and
# refuses to report success unless every file matches afterwards.
set -euo pipefail

HOST="${HOST:-bf-build}"
SRC="${SRC:-/root/github-repo/huddefs/scripts}"
DEST="${DEST:-/usr/local/bin}"

# Everything the builder invokes by name. resolve-capabilities.py is here
# because hud-build now dies without it rather than silently writing capability
# strings into Depends.
TOOLS="hud-build hud-test hud-scan-deps resolve-capabilities.py"

echo "deploying to $HOST:$DEST from $SRC"
for t in $TOOLS; do
    [ -f "$SRC/$t" ] || { echo "missing in checkout: $t" >&2; exit 2; }
done

# Uncommitted local edits are a common way for the two to diverge in the other
# direction — deployed ahead of git. Say so rather than hiding it.
if command -v git >/dev/null && git -C "$(dirname "$SRC")" status --porcelain scripts/ | grep -q .; then
    echo "note: scripts/ has uncommitted changes; deploying the working tree"
fi

# Build the argument lists as single space-separated strings. A $( ... ) that
# echoes one path per line becomes multiple LINES inside the remote command
# string, so `chmod 755 <paths>` turned into chmod plus one bare invocation of
# each tool — they ran with no arguments and printed their usage.
srcs=""; dests=""
for t in $TOOLS; do srcs="$srcs $SRC/$t"; dests="$dests $DEST/$t"; done

scp -q $srcs "$HOST:$DEST/"
ssh "$HOST" "chmod 755 $dests"

echo "verifying"
fail=0
for t in $TOOLS; do
    local_sum=$(sha256sum "$SRC/$t" | cut -d' ' -f1)
    remote_sum=$(ssh "$HOST" "sha256sum $DEST/$t" | cut -d' ' -f1)
    if [ "$local_sum" = "$remote_sum" ]; then
        printf '  %-26s ok\n' "$t"
    else
        printf '  %-26s MISMATCH\n' "$t"
        fail=1
    fi
done
[ "$fail" -eq 0 ] || { echo "deploy verification failed" >&2; exit 1; }
echo "all tooling in sync on $HOST"
