#!/bin/bash
# Build a genuinely minimal build rootfs: the BlackFlag base system plus the
# nine bootstrap packages, and nothing else.
#
# This replaces the F6 approach, which produced the current root by DELETING
# files from a fully populated tree. That left 2,226 dangling symlinks, 242
# packages still registered in share/hud/info, and 5,002 orphaned files — a root
# that answers "libpng.so is here" and then cannot link it, which is worse than
# one that answers "absent". See docs/rootfs-audit.md.
#
# Two things are removed that deleting-from-populated could never have removed
# cleanly:
#
#   /opt/hud             everything, then the nine are unpacked back in
#   the 66 escaped pip installs in /usr/lib/python3.13/site-packages, which are
#   the payloads the empty python3-* packages should have shipped and which
#   landed on the build server instead
#
# Run on bf-build. It writes several gigabytes, which is exactly the load that
# drops bf-repo's USB link.
set -euo pipefail

# Either snapshot works as the base, because only /usr is taken from it and
# both carry the same base system. The minimal one is the default simply because
# it is 1.1 G instead of 2.8 G and is already on bf-build; /opt/hud is discarded
# from whichever is used, so its state does not matter.
SRC="${SRC:-/var/hud-build/base-rootfs-minimal.tar.zst}"
POOL="${POOL:-/var/hud-build/pool}"                  # .hud files for the nine
OUT="${OUT:-/var/hud-build/base-rootfs-minimal-clean.tar.zst}"
WORK="${WORK:-/var/hud-build/work/mkroot}"
# DRYRUN=1 reports what the escaped-pip removal would do, against any root, and
# exits without writing anything. Verified this way before the destructive path
# was ever run: 66 trees removed, 11 base-system ones kept — cffi, cryptography,
# flit_core, jinja2, markupsafe, meson, packaging, pip, pycparser, setuptools,
# wheel — and zero collisions between the two sets.
DRYRUN="${DRYRUN:-0}"

# The bootstrap floor: the hud client cannot fetch anything without these, so
# they are the one set that must be present before any package can be installed.
# /usr/bin/curl is a symlink into /opt/hud/bin/curl, which is why curl is here
# and why deleting /opt/hud wholesale needs them unpacked back with tar rather
# than with the client.
FLOOR="curl openssl zlib zstd brotli nghttp2 libidn2 libpsl libunistring"

die() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }

# Shared by the dry run and the real one, so the thing verified is the thing
# that runs.
prune_escaped_pip() {
    python3 - "$1" "${2:-0}" <<'PY'
import datetime, os, sys, shutil
sp, dry = sys.argv[1], sys.argv[2] == "1"
if not os.path.isdir(sp):
    print(f"    no site-packages at {sp}"); raise SystemExit(0)
# The genuine base-system entries are dated 2025; the 66 that escaped from the
# empty python3-* builds are all dated 2026-01-28. Going by date rather than by
# name means one added to the set later is still caught.
CUTOFF = datetime.date(2026, 1, 1)
removed = kept = 0
kept_targets, drop_targets, drops = set(), set(), []
def tops(distinfo):
    rec = os.path.join(distinfo, "RECORD")
    out = set()
    if os.path.exists(rec):
        for line in open(rec, errors="replace"):
            f = line.split(",")[0].strip()
            if f and not f.startswith(("..", "/")):
                out.add(f.split("/")[0])
    return out
for d in sorted(os.listdir(sp)):
    if not d.endswith(".dist-info"):
        continue
    p = os.path.join(sp, d)
    if datetime.date.fromtimestamp(os.stat(p).st_mtime) < CUTOFF:
        kept += 1; kept_targets |= tops(p); continue
    t = tops(p); drop_targets |= t; drops.append((p, t)); removed += 1
clash = drop_targets & kept_targets
if clash:
    print(f"    REFUSING: these belong to both a kept and a removed dist: {sorted(clash)}")
    raise SystemExit(1)
if dry:
    print(f"    dry run: would remove {removed} escaped trees, keep {kept} base-system ones")
    raise SystemExit(0)
for p, t in drops:
    for name in t:
        q = os.path.join(sp, name)
        if os.path.isdir(q):
            shutil.rmtree(q, ignore_errors=True)
        elif os.path.exists(q):
            os.remove(q)
    shutil.rmtree(p, ignore_errors=True)
print(f"    removed {removed} escaped dist-info trees, kept {kept} base-system ones")
PY
}
ok()  { echo -e "\033[32m[✓]\033[0m $*"; }
step(){ echo -e "\033[34m==>\033[0m $*"; }

if [ "$DRYRUN" = 1 ]; then
    TARGET="${1:-/var/hud-build/roots/minimal}/usr/lib/python3.13/site-packages"
    echo "dry run against $TARGET"
    prune_escaped_pip "$TARGET" 1
    exit $?
fi

[ -f "$SRC" ] || die "no source rootfs at $SRC"
[ -d "$POOL" ] || die "no pool at $POOL — copy the nine .hud files there, or set POOL"

for p in $FLOOR; do
    ls "$POOL"/"$p"-*.hud >/dev/null 2>&1 || die "pool is missing $p"
done
ok "all nine bootstrap packages present in $POOL"

R="$WORK/root"
# systemd-nspawn derives the machine name from the directory's basename, so a
# root at .../mkroot/root registers as "root" — and collides with any build
# running at the same time ("Machine 'root' already exists"), which shows up as
# the postinsts and the curl check failing for no visible reason. Name it.
MACHINE="mkroot-$$"
rm -rf "$WORK"; mkdir -p "$R"

step "extracting the populated base ($(du -h "$SRC" | cut -f1))"
zstd -dc "$SRC" | tar -x -C "$R" --numeric-owner

# ---------------------------------------------------------------- /opt/hud ---
step "removing /opt/hud entirely"
# Not selective deletion. Selective deletion is what produced the current root:
# it leaves symlinks whose targets are gone, and metadata for packages whose
# files are not there. Start from nothing and put back only the floor.
rm -rf "$R/opt/hud"
mkdir -p "$R/opt/hud"

step "unpacking the nine bootstrap packages with tar, not with the client"
# The client cannot run yet — /usr/bin/curl points into the /opt/hud that was
# just deleted — so the floor goes in with tar, exactly as `hud install` would
# have extracted it.
for p in $FLOOR; do
    a=$(ls "$POOL"/"$p"-*.hud | head -1)
    tar xzf "$a" -C "$R" --numeric-owner
    printf '    %-14s %s\n' "$p" "$(basename "$a")"
done

step "running the floor's postinst scripts"
for p in $FLOOR; do
    s="$R/opt/hud/share/hud/info/$p/postinst"
    [ -x "$s" ] || continue
    if ! systemd-nspawn -q --machine="$MACHINE" -D "$R" \
            /bin/bash -c "/opt/hud/share/hud/info/$p/postinst" >/dev/null 2>&1; then
        echo "    warning: $p postinst returned non-zero"
    fi
done

# ------------------------------------------------- the escaped pip installs ---
step "removing the payloads that escaped into the base system's Python"
# The 66 empty python3-* packages ran pip without --root=$DESTDIR, so their
# payloads installed into the BUILD SERVER's own Python and this snapshot
# inherited them. A build root that carries them silently satisfies imports that
# no package provides.
prune_escaped_pip "$R/usr/lib/python3.13/site-packages" 0

# ------------------------------------------------------------------ verify ---
step "verifying"
dangling=$(find "$R/opt/hud" -xtype l 2>/dev/null | wc -l)
registered=$(ls "$R/opt/hud/share/hud/info" 2>/dev/null | wc -l)
echo "    packages registered : $registered   (expected 9)"
echo "    dangling symlinks   : $dangling   (expected 0)"

[ "$registered" -eq 9 ] || die "expected 9 registered packages, found $registered"
[ "$dangling" -eq 0 ]   || die "$dangling dangling symlinks remain — the whole point of this script"

systemd-nspawn -q --machine="$MACHINE" -D "$R" /bin/bash -c \
    'command -v curl >/dev/null && curl --version >/dev/null' \
    || die "curl does not run in the new root — the bootstrap floor is incomplete"
ok "curl runs; the client can fetch"

step "packing $OUT"
tar -C "$R" -cf - . | zstd -T0 -19 -q -o "$OUT" -f
ok "$OUT ($(du -h "$OUT" | cut -f1))"

echo
echo "Next: extract it to the roots directory the builder overlays, and keep the"
echo "old one until a batch has been rebuilt against this:"
echo "    prepare-roots.sh $OUT"
