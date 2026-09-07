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

SRC="${SRC:-/var/hud-build/base-rootfs.tar.zst}"     # the FULL populated snapshot
POOL="${POOL:-/var/hud-build/pool}"                  # .hud files for the nine
OUT="${OUT:-/var/hud-build/base-rootfs-minimal-clean.tar.zst}"
WORK="${WORK:-/var/hud-build/work/mkroot}"

# The bootstrap floor: the hud client cannot fetch anything without these, so
# they are the one set that must be present before any package can be installed.
# /usr/bin/curl is a symlink into /opt/hud/bin/curl, which is why curl is here
# and why deleting /opt/hud wholesale needs them unpacked back with tar rather
# than with the client.
FLOOR="curl openssl zlib zstd brotli nghttp2 libidn2 libpsl libunistring"

die() { echo -e "\033[31m[✗]\033[0m $*" >&2; exit 1; }
ok()  { echo -e "\033[32m[✓]\033[0m $*"; }
step(){ echo -e "\033[34m==>\033[0m $*"; }

[ -f "$SRC" ] || die "no source rootfs at $SRC"
[ -d "$POOL" ] || die "no pool at $POOL — copy the nine .hud files there, or set POOL"

for p in $FLOOR; do
    ls "$POOL"/"$p"-*.hud >/dev/null 2>&1 || die "pool is missing $p"
done
ok "all nine bootstrap packages present in $POOL"

R="$WORK/root"
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
    systemd-nspawn -q -D "$R" /bin/bash -c "/opt/hud/share/hud/info/$p/postinst" \
        >/dev/null 2>&1 || echo "    warning: $p postinst returned non-zero"
done

# ------------------------------------------------- the escaped pip installs ---
step "removing the payloads that escaped into the base system's Python"
# The 66 empty python3-* packages ran pip without --root=$DESTDIR, so their
# payloads installed into the BUILD SERVER's own Python and this snapshot
# inherited them. A build root that carries them silently satisfies imports that
# no package provides.
SP="$R/usr/lib/python3.13/site-packages"
if [ -d "$SP" ]; then
    python3 - "$SP" <<'PY'
import datetime, os, sys, shutil
sp = sys.argv[1]
# The genuine base-system entries are dated 2025; the 66 escaped ones are all
# dated 2026-01-28. Going by date rather than by name means a package added to
# the 66 later is still caught.
CUTOFF = datetime.date(2026, 1, 1)
removed = kept = 0
for d in sorted(os.listdir(sp)):
    if not d.endswith(".dist-info"):
        continue
    p = os.path.join(sp, d)
    if datetime.date.fromtimestamp(os.stat(p).st_mtime) < CUTOFF:
        kept += 1
        continue
    # RECORD lists every file the install placed, relative to site-packages.
    rec = os.path.join(p, "RECORD")
    targets = set()
    if os.path.exists(rec):
        for line in open(rec, errors="replace"):
            f = line.split(",")[0].strip()
            if f and not f.startswith(("..", "/")):
                targets.add(f.split("/")[0])
    for t in targets:
        q = os.path.join(sp, t)
        if os.path.isdir(q):
            shutil.rmtree(q, ignore_errors=True)
        elif os.path.exists(q):
            os.remove(q)
    shutil.rmtree(p, ignore_errors=True)
    removed += 1
print(f"    removed {removed} escaped dist-info trees, kept {kept} base-system ones")
PY
fi

# ------------------------------------------------------------------ verify ---
step "verifying"
dangling=$(find "$R/opt/hud" -xtype l 2>/dev/null | wc -l)
registered=$(ls "$R/opt/hud/share/hud/info" 2>/dev/null | wc -l)
echo "    packages registered : $registered   (expected 9)"
echo "    dangling symlinks   : $dangling   (expected 0)"

[ "$registered" -eq 9 ] || die "expected 9 registered packages, found $registered"
[ "$dangling" -eq 0 ]   || die "$dangling dangling symlinks remain — the whole point of this script"

systemd-nspawn -q -D "$R" /bin/bash -c \
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
