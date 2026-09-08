# What a hud package may own outside `/opt/hud`

Decided 2026-09-08. This was the open question blocking ten of the E7 packages
and, through `libvirt`, G5. It is answered here by what systemd and the
filesystem actually do, not by preference.

## The rule

A hud package **may** own files outside `/opt/hud`, in four specific places, and
each of them ships in `[install]` under `$DESTDIR` so it lands in `FILES` and
`hud remove` takes it away again.

| What | Where | Why there |
|---|---|---|
| systemd units | `/usr/local/lib/systemd/system/` | in systemd's search path; ranks above the base system's units; collides with nothing |
| compatibility symlinks | `/usr/lib64`, `/usr/lib`, `/usr/include`, `/usr/bin` | the prefix is not on the default library, header or program path |
| loader and profile drop-ins | `/etc/ld.so.conf.d/`, `/etc/profile.d/` | one file per package, named for it; nothing else edits them |
| wrapper programs and policy | `/usr/bin/`, `/usr/share/polkit-1/rules.d/` | program files, and untracked program files are worse than tracked ones |

A hud package **may not** own an admin-editable configuration file. Those ship
as `<name>.default` inside the prefix, and `[postinst]` copies one into place
**only if the target does not exist**.

## Why systemd units are not in `/etc/systemd/system`

That is the administrator's directory. A package writing there outranks every
override an admin can make and cannot be masked the normal way.

Nor `/opt/hud/lib/systemd/system`, which is where E7 first put `dhcpcd`'s unit.
**systemd does not search it:**

```
$ systemctl show --property=UnitPath
/etc/systemd/system.control  /run/systemd/system.control  /run/systemd/transient
/run/systemd/generator.early /etc/systemd/system  /etc/systemd/system.attached
/run/systemd/system  /run/systemd/system.attached  /run/systemd/generator
/usr/local/lib/systemd/system  /usr/lib/systemd/system  /run/systemd/generator.late
```

So the unit shipped, was tracked, and did nothing. That was a real defect
introduced by E7 and it is fixed.

Nor `/usr/lib/systemd/system`, the vendor directory, because the base system
already has units there — `virtqemud-admin.socket`, `virtlogd.service`,
`virtlockd.service` among them — that no hud package tracks. Shipping over them
would make `hud remove libvirt` delete files belonging to the base system.

`/usr/local/lib/systemd/system` is in the search path, is empty, ranks **above**
`/usr/lib/systemd/system` so a hud unit wins over a stale base one, and ranks
**below** `/etc/systemd/system` so an admin override still wins over both. It is
what the directory is for.

## Why config files are `.default` and copied conditionally

`/etc/pam.d/system-auth` is the clearest case. v1's `linux-pam` overwrites it,
`system-account`, `system-session`, `system-password` and `other`
unconditionally on every install. Getting that wrong locks every user out of the
machine. Shipping the file and letting `hud remove` delete it is worse still.

So the package ships `/opt/hud/share/<pkg>/defaults/<name>`, and `[postinst]`
copies it only when the target is absent. The default is tracked and removable;
the live file belongs to the administrator from the moment it exists. This is
`CLAUDE.md` rule 5, applied.

## The one genuine conflict

`firewalld` and `libvirt` both write `/etc/firewalld/zones/libvirt.xml`.
Whichever installs last wins, silently. The zone describes libvirt, so **it
ships with `libvirt` alone** and `firewalld` drops it.

## What this does not decide

The FHS-versus-`/opt/hud` question in the hard gate is still open. This is the
narrow version — which specific directories a package may reach into, and under
what discipline — and it is deliberately a short list. If the distribution later
moves to FHS, every entry here becomes unnecessary rather than wrong.
