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
srcs=""; dests=""; tmps=""
for t in $TOOLS; do
    srcs="$srcs $SRC/$t"
    dests="$dests $DEST/$t"
    tmps="$tmps $DEST/.deploy-$t"
done

# Copy to a temporary name, then rename over the target.
#
# scp overwrites IN PLACE — it truncates the destination and writes into the
# same inode. bash reads a script LAZILY, so a hud-build that is mid-run keeps
# reading from its old byte offset in the new content and lands in the middle of
# a token. That is what killed a two-hour nodejs build the moment it finished
# compiling:
#     /usr/local/bin/hud-build: line 313: syntax error near unexpected token `network'
# The build had succeeded; the script running it had been replaced underneath.
#
# mv within the same filesystem is atomic and gives the new file a new inode, so
# anything already running keeps the file it started with.
for t in $TOOLS; do
    scp -q "$SRC/$t" "$HOST:$DEST/.deploy-$t"
done
ssh "$HOST" "for t in $TOOLS; do chmod 755 $DEST/.deploy-\$t && mv -f $DEST/.deploy-\$t $DEST/\$t; done"

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
