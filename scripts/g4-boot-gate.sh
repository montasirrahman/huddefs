#!/bin/bash
# G4 — the boot gate. A VM from the minimal rootfs must reach multi-user.target
# with systemd as PID 1.
#
# MUST run on bf-repo: it is the only machine with /dev/kvm.
#
# Never judged by exit code. A kernel panic and a clean boot both leave qemu
# running until the timeout, so both "succeed" if you look at $?. This reads the
# console log for a marker that can only be printed by a unit systemd ordered
# after multi-user.target, and treats a timeout with no marker as a failure.
set -uo pipefail

IMG="${IMG:-/var/hud-build/g4/rootfs.img}"
KERNEL="${KERNEL:-/boot/vmlinuz-6.16.1-lfs-12.4-systemd}"
LOG="${LOG:-/var/hud-build/g4/boot-$(date -u +%Y%m%dT%H%M%SZ).log}"
TIMEOUT="${TIMEOUT:-180}"
MEM="${MEM:-1024}"

fail() { echo -e "\033[31m[FAIL]\033[0m $*"; exit 1; }
ok()   { echo -e "\033[32m[ OK ]\033[0m $*"; }

[ -f "$IMG" ]    || fail "no image at $IMG — run g4-build-image.sh"
[ -f "$KERNEL" ] || fail "no kernel at $KERNEL"
[ -c /dev/kvm ]  || fail "no /dev/kvm — this gate must run on bf-repo"

# A qemu left over from an interrupted run holds a write lock on the image, and
# the next run then fails at stage 1 with no kernel output at all — which reads
# exactly like a broken image. Clear it and say so.
if pgrep -f "qemu-system-x86_64.*$(basename "$IMG")" >/dev/null 2>&1; then
    echo "a previous qemu still holds $IMG; terminating it"
    pkill -f "qemu-system-x86_64.*$(basename "$IMG")" || true
    sleep 2
fi

echo "image   : $IMG"
echo "kernel  : $KERNEL"
echo "timeout : ${TIMEOUT}s"
echo "log     : $LOG"
echo

# -no-reboot so a panic stops instead of looping; the marker unit powers off on
# success, so a clean run ends well before the timeout.
timeout "$TIMEOUT" qemu-system-x86_64 \
    -enable-kvm -m "$MEM" -smp "${SMP:-1}" -nographic -no-reboot \
    -kernel "$KERNEL" \
    -drive file="$IMG",format=raw,if=virtio \
    -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
    -append "console=ttyS0 root=/dev/vda rw systemd.unit=multi-user.target" \
    > "$LOG" 2>&1
rc=$?

echo "qemu exited $rc after $(wc -l < "$LOG") lines of console output"
echo "--- checks ---"

# Read the log, in the order the boot happens, so a failure isolates to a stage.
grep -q "Linux version" "$LOG" \
    && ok "stage 1: kernel booted" \
    || fail "stage 1: the kernel produced no output at all"

grep -qE "EXT4-fs \(vda\): mounted filesystem|VFS: Mounted root .* on device" "$LOG" \
    && ok "stage 2: the image mounted as root" \
    || fail "stage 2: root was not mounted from /dev/vda — check the -append root= and CONFIG_VIRTIO_BLK"

grep -qE "systemd\[1\]|Detected virtualization" "$LOG" \
    && ok "stage 3a: systemd is PID 1" \
    || fail "stage 3a: systemd never started as PID 1"

if grep -q "G4-BOOT-OK" "$LOG"; then
    ok "stage 3b: reached multi-user.target — $(grep -m1 -o 'G4-BOOT-OK.*' "$LOG" | tr -d '\r')"
else
    echo
    echo "last 25 lines of console:"
    sed -e 's/\r$//' "$LOG" | tail -25 | sed 's/^/    /'
    fail "stage 3b: multi-user.target was never reached (timeout or panic)"
fi

pk=$(grep -m1 -o 'G4-PACKAGES=[0-9]*' "$LOG" | cut -d= -f2 | tr -d '\r')
ok "image has ${pk:-0} packages registered (see docs/rootfs-audit.md — it should be 9)"

# Stage 4 only runs if g4-install-gate.sh prepared the image for it.
if grep -q "G4-UPDATE-DONE" "$LOG"; then
    grep -qE "packages available" "$LOG" \
        && ok "stage 4a: the VM reached the repository — $(grep -m1 -o '[0-9]* packages available.*' "$LOG" | tr -d '\r')" \
        || fail "stage 4a: hud update produced no package list. It exits 0 when it fails, so check the log, not the code"
    if grep -q "G4-INSTALL-OK" "$LOG"; then
        ok "stage 4b: installed from unstable — $(grep -m1 -o 'G4-INSTALL-OK.*' "$LOG" | tr -d '\r')"
    else
        echo
        sed -e 's/\r$//' "$LOG" | grep -A20 'G4-UPDATE-DONE' | tail -25 | sed 's/^/    /'
        fail "stage 4b: the package did not land. hud install exits 0 on failure; this checked the filesystem"
    fi
else
    echo "      (stage 4 not prepared — run g4-install-gate.sh to enable it)"
fi

if grep -qiE "Kernel panic|BUG: unable to handle|Call Trace" "$LOG"; then
    fail "a panic or oops appears in the log despite reaching the target"
fi
grep -ciE "Failed to start" "$LOG" | while read -r n; do
    [ "$n" -gt 0 ] && echo -e "\033[33m[warn]\033[0m $n units failed to start:" \
        && grep -iE "Failed to start" "$LOG" | sed -e 's/\r$//' | sed 's/^/    /' | head -10
done

echo
ok "G4 PASSED"
