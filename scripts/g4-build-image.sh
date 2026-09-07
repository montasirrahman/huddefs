#!/bin/bash
# G4 step 1 — turn the minimal rootfs tarball into a bootable raw disk image.
#
# Runs on bf-repo, which has the only /dev/kvm. That machine's disk is USB-
# attached and its failure mode is sustained write load, so this writes the
# image once and skips the work if the image is already newer than the tarball.
#
# The image is deliberately built from the SAME tarball the builds use. A boot
# gate that tests a specially prepared image tests the preparation, not the
# distribution.
set -euo pipefail

TARBALL="${1:-/var/hud-build/base-rootfs-minimal.tar.zst}"
IMG="${2:-/var/hud-build/g4/rootfs.img}"
SIZE_GB="${SIZE_GB:-6}"

[ -f "$TARBALL" ] || { echo "no rootfs tarball at $TARBALL" >&2; exit 2; }
mkdir -p "$(dirname "$IMG")"

if [ -f "$IMG" ] && [ "$IMG" -nt "$TARBALL" ]; then
    echo "image is newer than the tarball; keeping $IMG ($(du -h "$IMG" | cut -f1))"
    exit 0
fi

MNT=$(mktemp -d /var/hud-build/g4/mnt-XXXXXX)
cleanup() {
    mountpoint -q "$MNT" && umount "$MNT" || true
    rmdir "$MNT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "==> creating a ${SIZE_GB}G sparse image"
rm -f "$IMG"
truncate -s "${SIZE_GB}G" "$IMG"

echo "==> mkfs.ext4"
mkfs.ext4 -q -F -L bfroot "$IMG"

echo "==> mounting and extracting the rootfs"
mount -o loop "$IMG" "$MNT"
zstd -dc "$TARBALL" | tar -x -C "$MNT" --numeric-owner

echo "==> making it bootable as a disk rather than a container"
# The tarball is a container root: no fstab, and nothing that expects a block
# device. Both of these are the image's business, not the distribution's, so
# they are written here rather than baked into the rootfs every build uses.
cat > "$MNT/etc/fstab" <<'FSTAB'
# G4 boot-gate image
/dev/vda   /       ext4    defaults,noatime   0 1
FSTAB

# A serial console, because the gate reads the boot log and there is no display.
mkdir -p "$MNT/etc/systemd/system/getty.target.wants"
ln -sfn /usr/lib/systemd/system/serial-getty@.service \
        "$MNT/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service" 2>/dev/null || true

# The marker unit. The gate must not infer success from qemu's exit code — a
# kernel panic and a clean boot both leave qemu running until the timeout, so
# both would "succeed". This prints a string that can only appear if systemd
# reached multi-user.target as PID 1, then powers the machine off so a passing
# run does not wait out the timeout.
cat > "$MNT/etc/systemd/system/g4-marker.service" <<'UNIT'
[Unit]
Description=G4 boot gate marker
After=multi-user.target
Requires=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=no
StandardOutput=journal+console
ExecStart=/bin/sh -c 'echo "G4-BOOT-OK pid1=$(cat /proc/1/comm) target=multi-user"'
ExecStart=/bin/sh -c 'echo "G4-PACKAGES=$(ls /opt/hud/share/hud/info 2>/dev/null | wc -l)"'
ExecStartPost=/bin/sh -c 'sleep 1; systemctl poweroff --no-block'

[Install]
WantedBy=multi-user.target
UNIT
mkdir -p "$MNT/etc/systemd/system/multi-user.target.wants"
ln -sfn ../g4-marker.service \
        "$MNT/etc/systemd/system/multi-user.target.wants/g4-marker.service"

# Root must be able to log in on the console if a human needs to look.
sed -i 's/^root:[^:]*:/root::/' "$MNT/etc/shadow" 2>/dev/null || true

sync
umount "$MNT"
trap - EXIT INT TERM
cleanup

echo "==> done: $IMG ($(du -h --apparent-size "$IMG" | cut -f1) apparent, $(du -h "$IMG" | cut -f1) on disk)"
