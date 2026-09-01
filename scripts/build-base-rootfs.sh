#!/bin/bash
# =============================================================================
# build-base-rootfs.sh — create the golden build environment(s) for hud-build
#
#   build-base-rootfs.sh minimal     # default; what builds should use
#   build-base-rootfs.sh full        # a snapshot of this machine as-is
#
# WORKFLOW.md step 2.
#
# -----------------------------------------------------------------------------
# WHY MINIMAL IS THE DEFAULT
# -----------------------------------------------------------------------------
# The `full` rootfs is a snapshot of bf-repo with all 245 packages installed. A
# build inside it succeeds whether or not its Build-Depends are correct, because
# every dependency is already present. Converting definitions against it would
# produce green builds carrying dependency data nobody had verified — the exact
# failure this pipeline exists to prevent.
#
# `minimal` removes everything the hud repository installed, leaving only the
# base BlackFlag (LFS) system and the hud client. A build then succeeds only if
# its Build-Depends actually name what it needs.
#
# When a build fails against minimal, the fix belongs in the DEFINITION's
# Build-Depends. Adding the package to this rootfs instead defeats the point.
#
# -----------------------------------------------------------------------------
# WHAT MINIMAL CONTAINS, AND WHY THERE IS NO PACKAGE LIST TO INSTALL
# -----------------------------------------------------------------------------
# BlackFlag is a Linux From Scratch derivative: the base system in /usr already
# provides the whole toolchain. Every tool a build needs to bootstrap was
# verified present in /usr on bf-repo, independent of /opt/hud:
#
#   toolchain    gcc cc make ld as ar readelf objdump strip nm
#   shell/core   bash coreutils sed grep gawk findutils diffutils file
#   archives     tar gzip xz zstd bzip2
#   build aids   patch pkg-config install
#   runtime      python3 curl sqlite3
#
# The copies under /opt/hud/bin are duplicates installed by hud packages
# (binutils, xz, zstd, python3, curl, sqlite), which is why removing /opt/hud
# costs nothing: PATH falls through to the base system's copies.
#
# So minimal is not built by installing a list of packages into an empty root.
# It is the base system with the hud-installed payload removed:
#
#   - /opt/hud/*        every file any hud package installed
#   - /var/lib/hud/db   the installed-package database, which otherwise still
#                       claims 241 packages are present and makes `hud install`
#                       skip them as already satisfied. hud's init_db() uses
#                       CREATE TABLE IF NOT EXISTS, so it recreates it empty.
#   - /var/cache/hud    cached .hud archives, so downloads are exercised
#
# Kept: /usr/local/bin/hud, /etc/hud/sources.list, and the CA bundle.
# =============================================================================
set -euo pipefail

MODE="${1:-minimal}"
case "$MODE" in
    minimal) DEFAULT_OUT=/var/hud-build/base-rootfs-minimal.tar.zst ;;
    full)    DEFAULT_OUT=/var/hud-build/base-rootfs.tar.zst ;;
    *) echo "usage: $0 [minimal|full] [output.tar.zst]" >&2; exit 2 ;;
esac
OUT="${2:-$DEFAULT_OUT}"

GREEN=$'\033[0;32m'; BLUE=$'\033[0;34m'; RED=$'\033[0;31m'; NC=$'\033[0m'
info() { echo "${BLUE}[INFO]${NC} $*"; }
ok()   { echo "${GREEN}[✓]${NC} $*"; }
die()  { echo "${RED}[✗]${NC} $*" >&2; exit 1; }

# The tools a build must be able to reach with /opt/hud empty. Checked against
# the base system explicitly, so this script fails here rather than producing a
# rootfs in which every build dies at [configure].
BASE_TOOLS="gcc cc make ld as ar readelf objdump strip nm bash sed grep gawk
            tar gzip xz zstd bzip2 patch diff find file pkg-config install
            python3 curl sqlite3"

for t in $BASE_TOOLS; do
    [ -x "/usr/bin/$t" ] || [ -x "/bin/$t" ] || [ -x "/usr/sbin/$t" ] \
        || die "base system is missing /usr/bin/$t — minimal rootfs would be unusable"
done
ok "base system provides all $(echo $BASE_TOOLS | wc -w) required tools"

[ -x /usr/local/bin/hud ]  || die "/usr/local/bin/hud missing"
[ -s /etc/hud/sources.list ] || die "/etc/hud/sources.list missing or empty"
curl -sI --max-time 20 https://github.com >/dev/null \
    || die "TLS verification is broken here; fix the CA store before snapshotting"
ok "hud client, sources.list and TLS all present"

# /etc/resolv.conf and /etc/machine-id are deliberately NOT shipped.
#
# The host's /etc/resolv.conf is a symlink to /run/systemd/resolve/stub-resolv.conf.
# /run is excluded, and the stub answers on 127.0.0.53, which nothing listens on
# inside a container — so shipping it gives a resolver that cannot resolve.
# systemd-nspawn provides a working /etc/resolv.conf at runtime when the image
# has none.
#
# Shipping the host's /etc/machine-id would give every container the same
# identity and make systemd refuse to link journals.
#
# Note for anyone tempted to "fix" this by adding them back through a second
# `tar -C overlay` argument: --exclude applies to every member of the archive
# regardless of which -C section it came from, so the overlay copies are
# excluded too and the result is the same. Verified the hard way.

COMMON_EXCLUDES=(
    --exclude='./proc/*'  --exclude='./sys/*'   --exclude='./dev/*'
    --exclude='./run/*'   --exclude='./tmp/*'   --exclude='./var/tmp/*'
    --exclude='./media/*' --exclude='./mnt/*'   --exclude='./lost+found'
    --exclude='./var/www/hud-repo'
    --exclude='./var/hud-build'
    --exclude='./var/hud-test'
    --exclude='./root/github-repo'
    --exclude='./root/blackflag'
    --exclude='./var/log/*'  --exclude='./var/cache/*'
    --exclude='./sources'    --exclude='./boot/*'
    --exclude='./etc/resolv.conf' --exclude='./etc/machine-id'
)

# Every file any hud package installed, taken from the packages' own FILES
# manifests. /opt/hud is not enough: openjdk installs into /opt/jdk-24.0.2+12,
# java-bin into /opt/OpenJDK-24.0.2-bin, and libvirt drops headers into
# /usr/include/libvirt, binaries into /usr/bin and units into /usr/lib/systemd.
# 1238 files sit outside /opt/hud. Leaving them behind would let a package build
# against a header or library it never declared.
#
# THE BOOTSTRAP EXCEPTION
#
# Nine packages have to stay, because the hud client cannot fetch anything
# without them. /usr/bin/curl is only a compatibility symlink to
# /opt/hud/bin/curl — the base LFS system ships no curl of its own — so
# stripping /opt/hud leaves `hud update` unable to download packages.list, and
# hud then reports "0 packages available" and every Build-Depends install
# silently resolves to nothing.
#
# The set is the runtime closure of /opt/hud/bin/curl, computed with readelf -d
# and mapped back to owning packages:
#
#   curl -> libcurl -> openssl, zlib, zstd, brotli, nghttp2, libidn2, libpsl,
#                      libunistring
#
# KNOWN LIMITATION: these nine are always present, so a Build-Depends entry
# naming one of them is never validated by a build against this rootfs. zlib is
# in the set, which is why libpng's `Build-Depends: zlib` cannot be proved
# necessary here. Every dependency outside these nine is genuinely validated.
BOOTSTRAP_PKGS="curl openssl zlib zstd brotli nghttp2 libidn2 libpsl libunistring"

PKG_MANIFEST=$(mktemp)
KEEP_MANIFEST=$(mktemp)
trap 'rm -f "$PKG_MANIFEST" "$KEEP_MANIFEST"' EXIT

: > "$KEEP_MANIFEST"
for bp in $BOOTSTRAP_PKGS; do
    [ -f "/opt/hud/share/hud/info/$bp/FILES" ] \
        || die "bootstrap package $bp is not installed; cannot build a usable minimal rootfs"
    sed 's|^|./|' "/opt/hud/share/hud/info/$bp/FILES" >> "$KEEP_MANIFEST"
done
sort -u -o "$KEEP_MANIFEST" "$KEEP_MANIFEST"

cat /opt/hud/share/hud/info/*/FILES 2>/dev/null \
    | sed 's|^|./|' | sort -u | comm -23 - "$KEEP_MANIFEST" > "$PKG_MANIFEST"
info "keeping $(wc -l < "$KEEP_MANIFEST") files for the bootstrap set: $BOOTSTRAP_PKGS"
info "package payload to strip: $(wc -l < "$PKG_MANIFEST") files from $(ls -d /opt/hud/share/hud/info/*/ 2>/dev/null | wc -l) packages"

# Trimmed from the MINIMAL image only; the full image keeps all of this so it
# stays a faithful snapshot for reproducing an old build.
#
# Everything here is documentation, translations, or caches belonging to tools
# that have no part in a build. Measured on the 4.9 GB minimal tree:
#   /usr/share/doc 234M  locale 104M  man 79M  info 34M  i18n 17M
#   /home 290M  /srv 40M
#   /root/.claude 542M  /root/.npm-global 221M  /root/.npm 70M  /root/.cache 11M
#
# NOT excluded, despite being on the original list, because the claim did not
# survive checking:
#   *.la  — 28 KB in total across the whole tree, so there is nothing to save,
#           and libtool is installed and reads them during linking.
#   *.a   — 142 MB, but the bulk is libc.a, libstdc++.a, libasan.a and libtsan.a.
#           Those are core toolchain: configure scripts probe for libc.a, and
#           -fsanitize builds need the sanitiser archives. Saving 3% of the image
#           is not worth a configure test failing in a way that looks like a
#           missing dependency.
MINIMAL_EXCLUDES=(
    --exclude-from="$PKG_MANIFEST"
    --exclude='./var/lib/hud/db/*'
    --exclude='./var/cache/hud'
    --exclude='./usr/share/doc/*'
    --exclude='./usr/share/man/*'
    --exclude='./usr/share/info/*'
    --exclude='./usr/share/locale/*'
    --exclude='./usr/share/gtk-doc/*'
    --exclude='./usr/share/i18n/*'
    --exclude='./home/*'
    --exclude='./srv/*'
    --exclude='./var/www'
    --exclude='./root/.claude'
    --exclude='./root/.npm'
    --exclude='./root/.npm-global'
    --exclude='./root/.cache'
)

mkdir -p "$(dirname "$OUT")"
info "Creating $MODE rootfs: $OUT"

if [ "$MODE" = minimal ]; then
    tar --zstd -cf "$OUT" -C / "${COMMON_EXCLUDES[@]}" "${MINIMAL_EXCLUDES[@]}" . || true
else
    tar --zstd -cf "$OUT" -C / "${COMMON_EXCLUDES[@]}" . || true
fi
# tar exits 1 on "file changed as we read it"; the checks below decide success.

[ -s "$OUT" ] || die "tarball was not created"

if [ "$MODE" = minimal ]; then
    leaked=$(tar --zstd -tf "$OUT" | sort -u | comm -12 - "$PKG_MANIFEST" | wc -l)
    [ "$leaked" -eq 0 ] || die "minimal rootfs still contains $leaked package-installed files"
    ok "no package payload present beyond the bootstrap set"
fi

ok "built $OUT ($(du -h "$OUT" | cut -f1))"
