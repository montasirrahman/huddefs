#!/bin/bash
# G5 step 0 — can the boot-gate VM run a guest of its own?
#
# G5 is "the VM starts libvirtd and boots a guest through it". Before any of the
# libvirt work is worth doing, one thing has to be true: the VM must have its
# own /dev/kvm. If nested virtualisation is unavailable the whole gate has to be
# designed differently — TCG instead of KVM, and minutes per boot instead of
# seconds — so this is worth knowing first and cheaply.
#
# Runs on bf-repo. -cpu host is what exposes vmx to the guest.
set -euo pipefail

IMG="${IMG:-/var/hud-build/g4/rootfs.img}"
KERNEL="${KERNEL:-/boot/vmlinuz-6.16.1-lfs-12.4-systemd}"
LOG="${LOG:-/var/hud-build/g4/nested-$(date -u +%Y%m%dT%H%M%SZ).log}"
TIMEOUT="${TIMEOUT:-150}"

fail() { echo -e "\033[31m[FAIL]\033[0m $*"; exit 1; }
ok()   { echo -e "\033[32m[ OK ]\033[0m $*"; }

host_nested=$(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null \
           || cat /sys/module/kvm_amd/parameters/nested 2>/dev/null || echo N)
[ "$host_nested" = "Y" ] || [ "$host_nested" = "1" ] \
    && ok "host: nested virtualisation enabled ($host_nested)" \
    || fail "host: nested virtualisation is off — set kvm_intel.nested=1"

pkill -f "qemu-system-x86_64.*$(basename "$IMG")" >/dev/null 2>&1 && sleep 2 || true

MNT=$(mktemp -d /var/hud-build/g4/mnt-XXXXXX)
trap 'mountpoint -q "$MNT" && umount "$MNT"; rmdir "$MNT" 2>/dev/null || true' EXIT
mount -o loop "$IMG" "$MNT"
cat > "$MNT/etc/systemd/system/g5-nested.service" <<'UNIT'
[Unit]
Description=G5 step 0 — is nested KVM available in here?
After=multi-user.target

[Service]
Type=oneshot
StandardOutput=journal+console
ExecStart=/bin/sh -c 'echo "G5-VMX=$(grep -c vmx /proc/cpuinfo)"'
ExecStart=/bin/sh -c 'modprobe kvm_intel 2>/dev/null; echo "G5-KVMDEV=$([ -c /dev/kvm ] && echo yes || echo no)"'
ExecStart=/bin/sh -c 'echo "G5-NESTED=$(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo unavailable)"'
ExecStartPost=/bin/sh -c 'sleep 1; systemctl poweroff --no-block'

[Install]
WantedBy=multi-user.target
UNIT
# Step 0 owns the shutdown; the other markers must not race it.
sed -i '/^ExecStartPost=/d' "$MNT/etc/systemd/system/g4-install.service" 2>/dev/null || true
ln -sfn ../g5-nested.service "$MNT/etc/systemd/system/multi-user.target.wants/g5-nested.service"
sync; umount "$MNT"; rmdir "$MNT"; trap - EXIT

echo "booting with -cpu host so vmx reaches the guest; log: $LOG"
timeout "$TIMEOUT" qemu-system-x86_64 \
    -enable-kvm -cpu host -m 1536 -smp "${SMP:-1}" -nographic -no-reboot \
    -kernel "$KERNEL" \
    -drive file="$IMG",format=raw,if=virtio \
    -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
    -append "console=ttyS0 root=/dev/vda rw systemd.unit=multi-user.target" \
    > "$LOG" 2>&1 || true

echo "--- checks ---"
grep -q "G4-BOOT-OK" "$LOG" || fail "the VM did not reach multi-user.target with -cpu host"
ok "the VM boots with -cpu host"

vmx=$(grep -m1 -o 'G5-VMX=[0-9]*' "$LOG" | cut -d= -f2 | tr -d '\r')
dev=$(grep -m1 -o 'G5-KVMDEV=[a-z]*' "$LOG" | cut -d= -f2 | tr -d '\r')
nst=$(grep -m1 -o 'G5-NESTED=[A-Za-z0-9]*' "$LOG" | cut -d= -f2 | tr -d '\r')

[ "${vmx:-0}" -gt 0 ] 2>/dev/null \
    && ok "guest: vmx present on ${vmx} cpu(s)" \
    || fail "guest: no vmx — -cpu host did not expose virtualisation"
[ "$dev" = yes ] \
    && ok "guest: /dev/kvm exists — G5 can use KVM for its nested guest" \
    || fail "guest: no /dev/kvm. G5 would have to fall back to TCG, which is minutes per boot"
echo "guest: kvm_intel.nested = ${nst:-unavailable}"
echo
ok "G5 step 0 PASSED — nested KVM is available"
