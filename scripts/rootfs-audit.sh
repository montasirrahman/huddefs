#!/bin/bash
# Audit a build root for the remains of packages that were removed from it.
#
# Written after the G4 boot gate reported "242 packages registered" in a rootfs
# documented as holding nine. The F6 shrink deleted package FILES but left the
# directory tree, the symlinks pointing into it, and each package's postinst —
# so /opt/hud is full of symlinks that resolve to nothing.
#
# That is not cosmetic. A configure test that finds libpng.so present and then
# cannot link it reports "libpng support requested but library not found",
# which is exactly how freetype failed in E4.
#
#   rootfs-audit.sh [ROOT]        report
#   CLEAN=1 rootfs-audit.sh [ROOT]  also delete dangling symlinks and empty dirs
set -euo pipefail

ROOT="${1:-/var/hud-build/roots/minimal}"
PREFIX="$ROOT/opt/hud"
CLEAN="${CLEAN:-0}"

[ -d "$PREFIX" ] || { echo "no /opt/hud under $ROOT" >&2; exit 2; }

echo "root   : $ROOT"
echo "mode   : $([ "$CLEAN" = 1 ] && echo 'REPORT AND CLEAN' || echo 'report only')"
echo

registered=$(ls "$PREFIX/share/hud/info" 2>/dev/null | wc -l)
echo "packages registered in share/hud/info : $registered"

# A symlink whose target does not resolve. `find -xtype l` is exactly this test
# and does not follow into the target, so a loop cannot hang it.
mapfile -t DANGLING < <(find "$PREFIX" -xtype l 2>/dev/null || true)
libs=0
for d in "${DANGLING[@]:-}"; do
    case "$d" in *lib*.so*|*.pc) libs=$((libs + 1)) ;; esac
done
echo "dangling symlinks                     : ${#DANGLING[@]} (${libs} library or pkg-config)"

mapfile -t EMPTYDIRS < <(find "$PREFIX" -type d -empty 2>/dev/null || true)
echo "empty directories                     : ${#EMPTYDIRS[@]}"

real=$(find "$PREFIX" -type f ! -type l 2>/dev/null | wc -l)
echo "real files remaining under /opt/hud   : $real"

if [ "${#DANGLING[@]}" -gt 0 ]; then
    echo
    echo "first 12 dangling library links:"
    printf '%s\n' "${DANGLING[@]}" | grep -E 'lib.*\.so|\.pc$' | head -12 | sed 's|^|    |'
fi

if [ "$CLEAN" = 1 ]; then
    echo
    echo "==> removing ${#DANGLING[@]} dangling symlinks"
    # A dangling symlink is useless by definition: nothing can open it, and its
    # only effect is to make a -f or -e test on the LINK NAME succeed for a file
    # that is not there. Removing them cannot break a working build.
    [ "${#DANGLING[@]}" -gt 0 ] && printf '%s\0' "${DANGLING[@]}" | xargs -0 rm -f
    echo "==> removing empty directories (repeatedly, so nested ones go too)"
    while true; do
        n=$(find "$PREFIX" -type d -empty -not -path "$PREFIX" 2>/dev/null | wc -l)
        [ "$n" -eq 0 ] && break
        find "$PREFIX" -type d -empty -not -path "$PREFIX" -delete 2>/dev/null || break
    done
    echo "==> after cleaning:"
    echo "    dangling symlinks : $(find "$PREFIX" -xtype l 2>/dev/null | wc -l)"
    echo "    empty directories : $(find "$PREFIX" -type d -empty 2>/dev/null | wc -l)"
    echo "    real files        : $(find "$PREFIX" -type f ! -type l 2>/dev/null | wc -l)"
    echo
    echo "NOTE: the real files that remain are still there. This removes the"
    echo "links that lie about what is installed; it does not turn the root into"
    echo "the clean base the documentation claims. See docs/rootfs-audit.md."
fi
