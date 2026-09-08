#!/bin/bash
# G5 step 1 — the smallest guest that can prove libvirt started it.
#
# The boot-gate image is 6 G and takes 40 seconds; nesting that inside a VM to
# prove libvirt works would make the gate slow enough to be skipped. This builds
# an initramfs of a few megabytes whose /init prints a marker and powers the
# machine off, so a pass takes seconds and a failure is unambiguous.
#
# Deliberately has no dependency on libvirt, so it can be built and verified
# before libvirt is fixed — and if G5 later fails, this having passed on its own
# separates "libvirt is broken" from "the guest never worked".
set -euo pipefail

OUT="${OUT:-/var/hud-build/g5}"
KERNEL="${KERNEL:-/boot/vmlinuz-6.16.1-lfs-12.4-systemd}"
MARKER="${MARKER:-G5-GUEST-ALIVE}"

mkdir -p "$OUT"
WORK=$(mktemp -d "$OUT/guest-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK"/{bin,dev,proc,sys,lib64,usr/lib}
# /lib and /usr/lib64 point at /usr/lib, which is the ONLY directory this
# system's loader searches — see the comment on carry(). /lib64 stays a real
# directory because the ELF interpreter path baked into every binary is
# /lib64/ld-linux-x86-64.so.2 and that file has to be there literally.
ln -sfn usr/lib "$WORK/lib"
ln -sfn lib     "$WORK/usr/lib64"

# A static busybox would be ideal and there is none here, so carry the system
# binaries the init actually calls, each with the libraries ldd reports.
#
# Resolved with ldd rather than guessed, and the SET of binaries matters just as
# much: a first version shipped only bash, and `mount` inside the init was then
# not found. The shell exited 127, the kernel killed PID 1, and the only symptom
# was
#     Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
# with 0x7f00 >> 8 = 127. Nothing in that message says "a binary is missing".
# Libraries go FLAT into /usr/lib, and that directory is not a guess:
#
#     $ /lib64/ld-linux-x86-64.so.2 --help
#     Shared library search path:
#       (libraries located via /etc/ld.so.cache)
#       /usr/lib (system search path)
#
# There is no ld.so.cache in an initramfs, so /usr/lib is the entire search
# path this loader has. Mirroring the original paths put bash's libreadline,
# libhistory and libncursesw under /opt/hud/lib where nothing would look, and
# /lib64 — the obvious guess — is not searched either on this merged-usr system.
# Every wrong version produced the same unhelpful message:
#     Kernel panic - not syncing: Attempted to kill init! exitcode=0x00007f00
# The way to find it was to extract the initramfs and chroot into it, which
# says plainly: "libreadline.so.8: cannot open shared object file".
carry() {
    local bin="$1" dst="$2"
    cp -L "$bin" "$WORK/bin/$dst"
    chmod 755 "$WORK/bin/$dst"
    ldd "$bin" 2>/dev/null | grep -oE '/[^ ]+\.so[^ ]*' | sort -u | while read -r lib; do
        [ -e "$lib" ] || continue
        case "$(basename "$lib")" in
            ld-linux-*) cp -Ln "$lib" "$WORK/lib64/$(basename "$lib")" 2>/dev/null || true ;;
            *)          cp -Ln "$lib" "$WORK/usr/lib/$(basename "$lib")" 2>/dev/null || true ;;
        esac
    done
}
carry /bin/bash sh
carry "$(command -v mount)" mount
carry "$(command -v uname)" uname
carry "$(command -v cat)"   cat
carry "$(command -v sleep)" sleep

cat > "$WORK/init" <<INIT
#!/bin/sh
# PID 1 in the inner guest. Everything it needs is in this file: no services, no
# fstab, no network. PATH must be set explicitly — init inherits none.
export PATH=/bin
mount -t proc  proc /proc 2>/dev/null
mount -t sysfs sys  /sys  2>/dev/null
echo
echo "$MARKER pid1=\$\$ kernel=\$(uname -r)"
echo "G5-GUEST-CMDLINE=\$(cat /proc/cmdline 2>/dev/null)"
echo
# Power off through the ACPI register: this guest has no systemd to ask.
echo o > /proc/sysrq-trigger 2>/dev/null
sleep 5
INIT
chmod 755 "$WORK/init"

( cd "$WORK" && find . | cpio -o -H newc --quiet ) | gzip -9 > "$OUT/guest-initramfs.img"
echo "built $OUT/guest-initramfs.img ($(du -h "$OUT/guest-initramfs.img" | cut -f1))"

# Prove it boots before anything downstream depends on it. Judged by log
# content with a hard timeout — a panic and a clean boot both leave qemu
# running, so the exit code says nothing.
echo "verifying it boots under qemu directly"
LOG="$OUT/guest-boot.log"
timeout 90 qemu-system-x86_64 -enable-kvm -m 512 -smp 1 -nographic -no-reboot \
    -kernel "$KERNEL" -initrd "$OUT/guest-initramfs.img" \
    -append "console=ttyS0 rdinit=/init panic=1" > "$LOG" 2>&1 || true

if grep -q "$MARKER" "$LOG"; then
    echo "[ OK ] $(grep -m1 -o "$MARKER.*" "$LOG" | tr -d '\r')"
    echo "       the guest is usable as G5's inner VM"
else
    echo "[FAIL] the guest did not reach its init"
    tail -20 "$LOG" | sed 's/^/    /'
    exit 1
fi
