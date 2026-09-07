# G5 — what is proven, and what it is waiting on

G5 is the integration gate: **the VM starts libvirtd and boots a guest through
it.** One precondition had to be settled before any of the libvirt work was
worth doing, and it is settled.

## Step 0 passes: nested KVM is available

`scripts/g5-nested-check.sh`, on bf-repo:

```
[ OK ] host: nested virtualisation enabled (Y)
[ OK ] the VM boots with -cpu host
[ OK ] guest: vmx present on 2 cpu(s)
[ OK ] guest: /dev/kvm exists — G5 can use KVM for its nested guest
       guest: kvm_intel.nested = Y
```

This mattered because the alternative changes the design of the gate rather than
one line of it. Without nested KVM the inner guest would have to run under TCG,
which is minutes per boot instead of seconds, and a gate that slow gets skipped.
`-cpu host` is what exposes `vmx`; the default `-cpu qemu64` does not.

## What G5 still needs, and it is not a virtualisation problem

**libvirt is not installable in a usable state**, and that is an E7 problem
rather than a G5 one.

The boot gate's own log shows it: `virtnetworkd.service` is one of the six units
that fail to start in the image. `libvirt` is one of the ten E7 packages blocked
on the open question of who owns files outside `/opt/hud` — its `[postinst]`
creates twenty-three things the package does not track, including
`/etc/libvirt/virtqemud.conf`, `/etc/libvirt/network.conf`, six unit files under
`/etc/systemd/system/`, and a polkit rule. None of them ships, so installing the
package gives you binaries and no working daemon.

So the order is:

1. Settle the `/etc` ownership question in `docs/needs-human.md`.
2. Fix `libvirt` (and `qemu`, which is in the same set) under whatever that
   decision is.
3. Rebuild both, publish to unstable.
4. Then G5: boot the gate image, `hud install libvirt qemu`, start `virtqemud`,
   define a domain, boot it, and check the inner guest's console for a marker —
   by log content and a hard timeout, exactly as G4 does.

## The inner guest

The gate image is 6 G and boots in about 40 seconds, which is too heavy to nest.
G5's inner guest should be the smallest thing that proves libvirt drove it: the
same `vmlinuz` with a few-megabyte initramfs whose `init` prints a marker and
powers off. Building that is a small job and does not depend on the decisions
above, so it can be done in parallel.

## Do not test G5 by exit code

The same rule as G4, and for a sharper reason: `virsh start` returns 0 as soon
as libvirt has *accepted* the domain, long before the guest has done anything.
The only honest signal is the inner guest's console output.
