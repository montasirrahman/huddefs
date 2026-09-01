#!/bin/bash
# =============================================================================
# prepare-roots.sh — extract each rootfs image once, for overlay-based builds
#
#   prepare-roots.sh [minimal|full|all]
#
# hud-build and hud-test mount an overlay over these trees instead of untarring
# a fresh copy per run. Extracting 4.9 GB and then deleting ~150k inodes, twice
# per package, cost 20-25 minutes per package on bf-repo regardless of how small
# the package was.
#
# The .tar.zst images are kept: they are the portable artifact for moving a
# build environment to bf-build. These extracted trees are local scratch and can
# be regenerated from the images at any time.
#
# Idempotent: re-extracts only if the tarball is newer than the last extraction.
# =============================================================================
set -euo pipefail

BUILD_ROOT="${HUD_BUILD_ROOT:-/var/hud-build}"
ROOTS_DIR="${HUD_ROOTS_DIR:-$BUILD_ROOT/roots}"

GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; RED=$'\033[0;31m'; NC=$'\033[0m'
info() { echo "${BLUE}[INFO]${NC} $*"; }
ok()   { echo "${GREEN}[✓]${NC} $*"; }
die()  { echo "${RED}[✗]${NC} $*" >&2; exit 1; }

prepare() {
    local name="$1" tarball="$2"
    local dest="$ROOTS_DIR/$name" stamp="$ROOTS_DIR/.$name.stamp"

    [ -f "$tarball" ] || { info "skip $name: no image at $tarball"; return 0; }

    local sig
    sig="$(stat -c '%Y %s' "$tarball")"

    if [ -d "$dest" ] && [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$sig" ]; then
        ok "$name already extracted and current ($(du -sh "$dest" | cut -f1))"
        return 0
    fi

    info "extracting $name from $(basename "$tarball")"
    rm -rf "$dest.new"
    mkdir -p "$dest.new"
    tar --zstd -xf "$tarball" -C "$dest.new"

    # A tree with no /usr is not a usable root; fail before swapping it in.
    [ -d "$dest.new/usr" ] || die "$name: extracted tree has no /usr"

    rm -rf "$dest.old"
    [ -d "$dest" ] && mv "$dest" "$dest.old"
    mv "$dest.new" "$dest"
    rm -rf "$dest.old"
    echo "$sig" > "$stamp"
    ok "$name ready ($(du -sh "$dest" | cut -f1))"
}

mkdir -p "$ROOTS_DIR"
case "${1:-all}" in
    minimal) prepare minimal "$BUILD_ROOT/base-rootfs-minimal.tar.zst" ;;
    full)    prepare full    "$BUILD_ROOT/base-rootfs.tar.zst" ;;
    all)     prepare minimal "$BUILD_ROOT/base-rootfs-minimal.tar.zst"
             prepare full    "$BUILD_ROOT/base-rootfs.tar.zst" ;;
    *) die "usage: $0 [minimal|full|all]" ;;
esac
