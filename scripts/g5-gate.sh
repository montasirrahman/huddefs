#!/bin/bash
# G5 — the integration gate: the VM starts libvirtd and boots a guest through it.
#
# Runs on bf-repo, the only machine with /dev/kvm. Nested KVM is proven
# (g5-nested-check.sh) and the inner guest is proven on its own
# (g5-build-guest.sh), so a failure here is libvirt's, which is the point.
#
# Judged by the INNER guest's console output. Not by virsh's exit code: `virsh
# start` returns 0 as soon as libvirt has accepted the domain, long before the
# guest has done anything, so an exit code here would pass on a domain that
# never ran.
set -uo pipefail

IMG="${IMG:-/var/hud-build/g4/rootfs.img}"
KERNEL="${KERNEL:-/boot/vmlinuz-6.16.1-lfs-12.4-systemd}"
GUEST="${GUEST:-/var/hud-build/g5/guest-initramfs.img}"
LOG="${LOG:-/var/hud-build/g5/gate-$(date -u +%Y%m%dT%H%M%SZ).log}"
TIMEOUT="${TIMEOUT:-600}"
MARKER="G5-GUEST-ALIVE"

fail() { echo -e "\033[31m[FAIL]\033[0m $*"; exit 1; }
ok()   { echo -e "\033[32m[ OK ]\033[0m $*"; }

for f in "$IMG" "$KERNEL" "$GUEST"; do
    [ -f "$f" ] || fail "missing: $f"
done
[ -c /dev/kvm ] || fail "no /dev/kvm — this gate must run on bf-repo"

pkill -f "qemu-system-x86_64.*$(basename "$IMG")" >/dev/null 2>&1 && sleep 2 || true

# --- put the inner guest and its kernel inside the outer image ---------------
MNT=$(mktemp -d /var/hud-build/g5/mnt-XXXXXX)
trap 'mountpoint -q "$MNT" && umount "$MNT"; rmdir "$MNT" 2>/dev/null || true' EXIT
mount -o loop "$IMG" "$MNT"

mkdir -p "$MNT/opt/g5"
cp "$GUEST"  "$MNT/opt/g5/guest-initramfs.img"
cp "$KERNEL" "$MNT/opt/g5/vmlinuz"

cat > "$MNT/opt/g5/guest.xml" <<'XML'
<domain type='kvm'>
  <name>g5guest</name>
  <memory unit='MiB'>512</memory>
  <vcpu>1</vcpu>
  <os>
    <type arch='x86_64' machine='pc'>hvm</type>
    <kernel>/opt/g5/vmlinuz</kernel>
    <initrd>/opt/g5/guest-initramfs.img</initrd>
    <cmdline>console=ttyS0 rdinit=/init panic=1</cmdline>
  </os>
  <features><acpi/></features>
  <on_poweroff>destroy</on_poweroff>
  <devices>
    <emulator>/opt/hud/bin/qemu-system-x86_64</emulator>
    <!-- The console goes to a FILE, because the gate reads it. A pty would
         need something attached to it and would be lost when the domain ends. -->
    <serial type='file'>
      <source path='/opt/g5/inner-console.log'/>
      <target port='0'/>
    </serial>
    <console type='file'>
      <source path='/opt/g5/inner-console.log'/>
      <target type='serial' port='0'/>
    </console>
  </devices>
</domain>
XML

cat > "$MNT/etc/systemd/system/g5-gate.service" <<UNIT
[Unit]
Description=G5 — start libvirt and boot a guest through it
After=multi-user.target

[Service]
Type=oneshot
StandardOutput=journal+console
StandardError=journal+console
Environment=PATH=/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin
# Network first: the same fixed SLIRP address the G4 gate uses, because nothing
# in this image brings an interface up and network-online.target never arrives.
# First interface with a BACKING DEVICE, not the first alphabetically.
# /sys/class/net lists virtual interfaces too, and the base image carries a
# leftover bond0 that sorts ahead of any real NIC — G4 spent three runs putting
# its address on a carrier-less bond and reporting the resulting failure as a
# setup problem. Only real NICs have a device/ symlink.
ExecStart=/bin/sh -c 'for d in /sys/class/net/*/device; do [ -e "\$d" ] || continue; IF=\$(basename "\$(dirname "\$d")"); break; done; \\
  [ -n "\$IF" ] || { echo "G5-NET-NONE no interface has a backing device"; exit 1; }; \\
  ip link set "\$IF" up; ip addr add 10.0.2.15/24 dev "\$IF" 2>/dev/null; \\
  ip route add default via 10.0.2.2 2>/dev/null; echo "G5-NET \$IF"'
ExecStart=/bin/sh -c 'hud update 2>&1 | tail -2'
ExecStart=/bin/sh -c 'hud install -y libvirt qemu 2>&1 | tail -15; echo "G5-INSTALL-RAN"'
# Checked on the filesystem, not by exit code: hud install exits 0 when it fails.
ExecStart=/bin/sh -c 'for b in /opt/hud/sbin/virtqemud /usr/sbin/virtqemud /opt/hud/bin/virsh /usr/bin/virsh; do [ -x "\$b" ] && echo "G5-HAVE \$b"; done; true'
ExecStart=/bin/sh -c 'systemctl daemon-reload; systemctl start virtqemud 2>&1 | tail -3; sleep 3; \\
  systemctl is-active virtqemud && echo "G5-LIBVIRTD-UP" || echo "G5-LIBVIRTD-DOWN"'
ExecStart=/bin/sh -c 'virsh --connect qemu:///system define /opt/g5/guest.xml 2>&1 | tail -3; \\
  virsh --connect qemu:///system start g5guest 2>&1 | tail -3; echo "G5-VIRSH-RAN"'
ExecStart=/bin/sh -c 'for i in 1 2 3 4 5 6 7 8 9 10 11 12; do \\
  grep -q "$MARKER" /opt/g5/inner-console.log 2>/dev/null && break; sleep 5; done; \\
  echo "=== inner guest console ==="; cat /opt/g5/inner-console.log 2>/dev/null | tail -25; \\
  echo "=== end inner console ==="'
ExecStartPost=/bin/sh -c 'sleep 2; systemctl poweroff --no-block'

[Install]
WantedBy=multi-user.target
UNIT

# This unit owns the shutdown; the earlier gates' markers must not race it.
sed -i '/^ExecStartPost=/d' "$MNT/etc/systemd/system/g4-install.service" 2>/dev/null || true
sed -i '/^ExecStartPost=/d' "$MNT/etc/systemd/system/g5-nested.service"  2>/dev/null || true
rm -f "$MNT/opt/g5/inner-console.log"
ln -sfn ../g5-gate.service "$MNT/etc/systemd/system/multi-user.target.wants/g5-gate.service"

sync; umount "$MNT"; rmdir "$MNT"; trap - EXIT

# --- run ---------------------------------------------------------------------
echo "booting the outer VM with -cpu host so it has its own /dev/kvm"
echo "log: $LOG"
# -snapshot for the same reason as the boot gate: the guest mounts this image
# as a read-write root, and G4's copy of this line let an interrupted run leave
# the filesystem dirty — the next boot died with "libcrypto.so.3: file too
# short", which reads like a broken distribution and was a truncated file. G4
# and G5 share one image, so a G5 run that is killed would break G4 too.
#
# The files staged above (the inner guest, its kernel, guest.xml) are written
# before boot and still apply: the overlay discards only what the guest writes.
timeout "$TIMEOUT" qemu-system-x86_64 \
    -enable-kvm -cpu host -m 2048 -smp "${SMP:-1}" -nographic -no-reboot -snapshot \
    -kernel "$KERNEL" \
    -drive file="$IMG",format=raw,if=virtio \
    -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
    -append "console=ttyS0 root=/dev/vda rw systemd.unit=multi-user.target" \
    > "$LOG" 2>&1 || true

echo "--- checks ---"
grep -q "G4-BOOT-OK" "$LOG"      && ok "the outer VM booted" || fail "the outer VM did not reach multi-user.target"
grep -q "packages available" "$LOG" && ok "it reached the repository" || fail "hud update produced no package list"
grep -q "G5-HAVE" "$LOG" \
    && ok "libvirt installed: $(grep -o 'G5-HAVE .*' "$LOG" | tr -d '\r' | tr '\n' ' ')" \
    || fail "no libvirt binaries on disk after install — hud install exits 0 when it fails, so this checked the filesystem"
grep -q "G5-LIBVIRTD-UP" "$LOG"  && ok "virtqemud is running" || {
    sed -e 's/\r$//' "$LOG" | grep -A6 'G5-INSTALL-RAN' | tail -12 | sed 's/^/    /'
    fail "libvirt installed but its daemon did not start"; }
grep -q "$MARKER" "$LOG" \
    && ok "the inner guest booted THROUGH libvirt — $(grep -m1 -o "$MARKER.*" "$LOG" | tr -d '\r')" \
    || { sed -e 's/\r$//' "$LOG" | sed -n '/inner guest console/,/end inner console/p' | tail -25 | sed 's/^/    /'
         fail "libvirt accepted the domain but the guest never printed its marker"; }
echo
ok "G5 PASSED"
