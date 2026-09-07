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
ExecStart=/bin/sh -c 'IF=\$(ls /sys/class/net | grep -v lo | head -1); \\
  ip link set "\$IF" up; \\
  ip addr add 10.0.2.15/24 dev "\$IF" 2>/dev/null || true; \\
  ip route add default via 10.0.2.2 2>/dev/null || true; \\
  echo "G4-NET iface=\$IF addr=\$(ip -4 -o addr show "\$IF" | awk "{print \\\$4}")"'
ExecStart=/bin/sh -c 'hud update 2>&1 | tail -5; echo "G4-UPDATE-DONE"'
ExecStart=/bin/sh -c 'hud install -y $PKG 2>&1 | tail -20; echo "G4-INSTALL-RAN"'
ExecStart=/bin/sh -c 'if [ -d /opt/hud/share/hud/info/$PKG ] && ls /opt/hud/lib/lib*yajl* >/dev/null 2>&1 || [ -f /opt/hud/share/hud/info/$PKG/FILES ]; then echo "G4-INSTALL-OK files=\$(wc -l < /opt/hud/share/hud/info/$PKG/FILES 2>/dev/null || echo 0)"; else echo "G4-INSTALL-MISSING"; fi'
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
