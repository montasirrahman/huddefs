#!/bin/bash
# G4 stage 4 — the booted VM installs a package from the unstable repository.
#
# The three stages before this prove the image boots. This one proves the thing
# the distribution is for: a machine that came up can fetch and install a
# package over the network from the repo bf-repo serves.
#
# Edits the image in place rather than rebuilding it: writing 3.4 G is the kind
# of sustained load that drops bf-repo's USB link, and the change is one unit
# file.
set -euo pipefail

IMG="${IMG:-/var/hud-build/g4/rootfs.img}"
PKG="${PKG:-yajl}"                     # small, no dependencies, in unstable
REPO="${REPO:-http://172.19.1.7/hud-unstable}"

[ -f "$IMG" ] || { echo "no image at $IMG" >&2; exit 2; }

MNT=$(mktemp -d /var/hud-build/g4/mnt-XXXXXX)
cleanup() { mountpoint -q "$MNT" && umount "$MNT" || true; rmdir "$MNT" 2>/dev/null || true; }
trap cleanup EXIT INT TERM

mount -o loop "$IMG" "$MNT"

cat > "$MNT/etc/hud/sources.list" <<SRC
# HUD Package Sources — G4 stage 4 points at the STAGING repository.
hud $REPO unstable main
SRC

cat > "$MNT/etc/systemd/system/g4-install.service" <<UNIT
[Unit]
Description=G4 stage 4 — install a package from the repository
After=multi-user.target

# Deliberately NOT After/Wants=network-online.target. Nothing in this image
# brings an interface up — there is no networkd configuration and no DHCP
# client — so network-online.target is never reached and the unit waits until
# the gate's timeout, which looks exactly like a hung install. The address is
# configured below instead: qemu's user-mode network is a fixed SLIRP subnet,
# 10.0.2.15 for the guest with the gateway at 10.0.2.2, so there is nothing to
# discover.

[Service]
Type=oneshot
StandardOutput=journal+console
StandardError=journal+console
Environment=PATH=/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin
# hud update and hud install both exit 0 when they fail — seven of eight client
# commands do — so nothing here trusts an exit code. Each step prints a marker
# the gate greps for, and the last one checks the FILESYSTEM for a file the
# package ships rather than asking the client whether it succeeded.
# The interface is the first one with a BACKING DEVICE, not the first one
# alphabetically. /sys/class/net also lists virtual interfaces, and the base
# image carries a leftover bond0 that sorts before any real NIC — so the address
# went onto a device with no carrier, hud update could not reach the repository,
# the unit never printed its marker, and the gate reported 'stage 4 not
# prepared' rather than a failure. Only real NICs have a device/ symlink.
ExecStart=/bin/sh -c 'for d in /sys/class/net/*/device; do [ -e "\$d" ] || continue; IF=\$(basename "\$(dirname "\$d")"); break; done; \\
  [ -n "\$IF" ] || { echo "G4-NET-NONE no interface has a backing device"; exit 1; }; \\
  ip link set "\$IF" up; \\
  ip addr add 10.0.2.15/24 dev "\$IF" 2>/dev/null || true; \\
  ip route add default via 10.0.2.2 2>/dev/null || true; \\
  echo "G4-NET iface=\$IF addr=\$(ip -4 -o addr show "\$IF" | awk "{print \\\$4}")"'
ExecStart=/bin/sh -c 'hud update 2>&1 | tail -5; echo "G4-UPDATE-DONE"'
ExecStart=/bin/sh -c 'hud install -y $PKG 2>&1 | tail -20; echo "G4-INSTALL-RAN"'
# Verify the FILESYSTEM, and verify it for whatever PKG is — the old check
# tested for a yajl library by name, so pointing PKG at anything else silently
# fell through to "a manifest exists", which is the client's own claim rather
# than evidence. Manifest paths are relative and have no leading slash.
ExecStart=/bin/sh -c 'F=/opt/hud/share/hud/info/$PKG/FILES; \\
  if [ ! -s "\$F" ]; then echo "G4-INSTALL-MISSING no manifest for $PKG"; exit 0; fi; \\
  n=0; hit=0; \\
  while read -r rel; do \\
    [ -n "\$rel" ] || continue; n=\$((n+1)); \\
    [ -e "/\$rel" ] && hit=\$((hit+1)); \\
  done < "\$F"; \\
  if [ "\$hit" -gt 0 ] && [ "\$hit" -eq "\$n" ]; then echo "G4-INSTALL-OK files=\$n present=\$hit"; \\
  else echo "G4-INSTALL-MISSING manifest lists \$n, on disk \$hit"; fi'
ExecStartPost=/bin/sh -c 'sleep 1; systemctl poweroff --no-block'

[Install]
WantedBy=multi-user.target
UNIT

# Stage 4 replaces stage 3's marker unit as the thing that powers off, so the
# two do not race to shut down.
sed -i '/^ExecStartPost=/d' "$MNT/etc/systemd/system/g4-marker.service"
ln -sfn ../g4-install.service \
        "$MNT/etc/systemd/system/multi-user.target.wants/g4-install.service"

# The package must not already be present, or the test proves nothing.
rm -rf "$MNT/opt/hud/share/hud/info/$PKG"

sync
umount "$MNT"
trap - EXIT INT TERM
cleanup
echo "image prepared: stage 4 will install '$PKG' from $REPO"
