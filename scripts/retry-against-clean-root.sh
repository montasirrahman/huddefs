#!/bin/bash
# Retry a set of packages against the regenerated build root, and say plainly
# whether the root was the cause.
#
# The point is the comparison, not the rebuild. Twelve E4 failures each named a
# library that exists in the old root only as a dangling symlink, and six of
# them failed with an error meaning "the library is there but unusable" —
# freetype's "libpng support requested but library not found" being the clearest.
# That is a hypothesis until the same definitions are built against a root
# without those links.
#
# Runs on bf-build. Builds only; it does not publish, because the question is
# which root a package needs, not whether the package is ready to ship.
set -uo pipefail

CLEAN="${CLEAN:-/var/hud-build/base-rootfs-minimal-clean.tar.zst}"
OLD="${OLD:-/var/hud-build/base-rootfs-minimal.tar.zst}"
H="${H:-/root/github-repo/huddefs/huddefs}"
OUT="${OUT:-/var/hud-build/clean-root-retry.json}"

# Default set: the six whose error message means "present but unusable", plus
# two whose errors were never read and should not be assumed either way.
PKGS="${*:-freetype libxslt libvorbis ncurses libXt libxcb gdb lcms2}"

[ -f "$CLEAN" ] || { echo "no clean rootfs at $CLEAN — run make-minimal-rootfs.sh" >&2; exit 2; }

echo "clean : $CLEAN"
echo "old   : $OLD"
echo "set   : $PKGS"
echo

printf '%-14s %-22s %-22s %s\n' PACKAGE "OLD ROOT" "CLEAN ROOT" VERDICT
echo "---------------------------------------------------------------------------"

results="{"
for p in $PKGS; do
    def="$H/$p/$p.huddef"
    [ -f "$def" ] || { printf '%-14s %s\n' "$p" "no definition"; continue; }

    HUD_BASE_ROOTFS="$OLD"   hud-build "$def" >"/tmp/retry-$p-old.log"   2>&1; rc_old=$?
    HUD_BASE_ROOTFS="$CLEAN" hud-build "$def" >"/tmp/retry-$p-clean.log" 2>&1; rc_clean=$?

    sig() { grep -aoE '(error|Error|ERROR)[:[:space:]].{0,40}' "$1" | tail -1 | tr -d '\n' | cut -c1-20; }
    o=$([ $rc_old   -eq 0 ] && echo OK || sig "/tmp/retry-$p-old.log")
    c=$([ $rc_clean -eq 0 ] && echo OK || sig "/tmp/retry-$p-clean.log")

    if   [ $rc_old -ne 0 ] && [ $rc_clean -eq 0 ]; then v="ROOT WAS THE CAUSE"
    elif [ $rc_old -eq 0 ] && [ $rc_clean -ne 0 ]; then v="REGRESSION — investigate"
    elif [ $rc_old -ne 0 ]; then                        v="not the root"
    else                                                v="fine either way"
    fi
    printf '%-14s %-22s %-22s %s\n' "$p" "${o:-fail}" "${c:-fail}" "$v"
    results="$results\"$p\":{\"old_rc\":$rc_old,\"clean_rc\":$rc_clean,\"verdict\":\"$v\"},"
done
echo "${results%,}}" > "$OUT"
echo
echo "written to $OUT"
