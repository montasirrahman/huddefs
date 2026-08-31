# HUD Package Definition Format — v2

Status: proposed. v1 is the format currently in `/var/www/hud-repo/sources/definitions/`.

This spec changes v1 as little as possible. The header stays Debian-style, the
build sections stay bash. Every change below exists to fix a specific defect
found in the v1 definitions.

---

## Why v2 exists

Five defects in v1, each addressed by one change here:

| Defect in v1 | Fix in v2 |
|---|---|
| `Source:` has no checksum, so builds are not reproducible | `Source-SHA256:` is mandatory |
| Builds `wget` and `pip install` from the network mid-build | Network is unavailable during build; patches live in the repo |
| `patch ... \|\| true` hides failures and ships wrong binaries | Build sections run under `set -euo pipefail` |
| One `Depends:` field holds both build tools and runtime libraries | Split into `Build-Depends:` and `Depends:` |
| `postinst` creates untracked files outside the package | `postinst` restrictions, plus `prerm` for cleanup |

---

## File naming and location

```
huddefs/<package>/<package>.huddef       # one canonical file per package
huddefs/<package>/patches/*.patch        # patches, committed to git
huddefs/<package>/files/*                # config files shipped with the package
```

One definition per package. The version lives *inside* the file, not in the
filename. This is the change that ends the `qemu-10.0.3.huddef` × 6 problem:
git holds the history, the filesystem holds one current version.

---

## Header fields

```
Package:          qemu
Version:          10.0.3
Epoch:            0
Architecture:     x86_64
Section:          virtualization
Description:      Full virtualization solution for Linux with KVM support

Source:           https://download.qemu.org/qemu-10.0.3.tar.xz
Source-SHA256:    2ea9d1a3e4bf5d2f9d8e9c... (64 hex chars)

Build-Depends:    glib, pixman, alsa-lib, dtc, libslirp, sdl2, meson, ninja, python3
Depends:          auto
Provides:         auto

Patches:          0001-python-fixes.patch
Service:
Maintainer:       you@blackflag.com.bd
```

### Required

| Field | Notes |
|---|---|
| `Package` | Lowercase, `[a-z0-9][a-z0-9+.-]*` |
| `Version` | Upstream version, unmodified |
| `Architecture` | `x86_64`, `aarch64`, or `noarch` |
| `Section` | Must be from the controlled list below |
| `Description` | One line |
| `Source` | URL or `none` for source-in-repo packages |
| `Source-SHA256` | Mandatory when `Source` is a URL. The build fails on mismatch. |
| `Build-Depends` | Everything needed to build. Comma-separated. |
| `Depends` | `auto` (recommended) or an explicit list |

### Optional

| Field | Default | Notes |
|---|---|---|
| `Epoch` | `0` | Bump only when upstream versioning goes backwards |
| `Provides` | `auto` | Sonames and pkg-config names, normally auto-detected |
| `Conflicts` | empty | Packages that cannot be installed alongside |
| `Patches` | empty | Filenames in `patches/`, applied with `-Np1` in listed order |
| `Service` | empty | systemd unit name if the package ships one |
| `Maintainer` | empty | |

### `Depends: auto`

The builder scans the finished package and derives runtime dependencies:

- `readelf -d` on every ELF binary → `DT_NEEDED` sonames → provides table
- `.pc` files → `Requires:` and `Requires.private:`
- `*.dist-info/METADATA` → `Requires-Dist`
- `#!` lines → interpreter packages

`Provides: auto` derives the other side: `DT_SONAME` from each shared library,
plus pkg-config names and Python distribution names.

Both fields resolve to **capability strings**, not package names —
`libssl.so.3`, not `openssl`. This survives package renames and catches soname
bumps, and it is what makes reverse-dependency queries exact instead of the
current `LIKE '%pkg%'` substring match.

Write an explicit list only when auto-detection genuinely cannot see the
dependency — a plugin loaded via `dlopen`, or a binary invoked by `exec`. Add a
comment saying why.

---

## Build sections

Unchanged from v1: `[configure]`, `[build]`, `[install]`, `[postinst]`.
Two new optional ones: `[check]` and `[prerm]`.

Every section runs under `set -euo pipefail`. Any failing command aborts the
build. If you truly need to ignore a failure, be explicit and say why:

```bash
chgrp kvm /opt/hud/libexec/qemu-bridge-helper || true   # group may not exist yet
```

`|| true` on a `patch` or `wget` is never acceptable.

### Environment provided by the builder

Do not set these yourself; v1 definitions repeat them in every section and they
belong in the builder:

```
PATH, PKG_CONFIG_PATH, LD_LIBRARY_PATH, CFLAGS, LDFLAGS
DESTDIR      staging root for [install]
SRCDIR       unpacked source tree
NPROC        parallelism for make -j
```

### `[check]` — new, optional

Runs inside the build container after `[install]`, against the staged tree.
Keep it under a minute; this is a smoke test, not upstream's full suite.

```
[check]
$DESTDIR/opt/hud/bin/qemu-system-x86_64 --version | grep -q "10.0.3"
```

### `[postinst]` — restrictions

Runs as root on the client after extraction. It may:

- run `ldconfig`
- create system users and groups
- register systemd units
- create a config file **only if it does not already exist**

It may **not**:

- create files outside the package's own prefix without recording them in `FILES`
- overwrite an existing config file
- download anything
- silently ignore failures

v1's qemu postinst violates three of these. Config files belong in `files/` and
are installed during `[install]`; symlinks into `/usr/bin` must be created in
`[install]` under `$DESTDIR` so they land in `FILES` and get removed cleanly.

### `[prerm]` — new, optional

Runs before removal. Undoes what `[postinst]` created that `FILES` does not
cover: stopping services, removing generated state.

---

## Network policy

The build container has **no network access** after the source tarball is
fetched and its hash verified.

This is what forces patches and vendored Python dependencies into git, where
they are reviewable and reproducible. A definition that needs `pip install
distlib` at build time should instead list `python3-distlib` in
`Build-Depends`, which is a package you already have.

---

## Controlled section list

```
core          libraries     development   python        security
system        network       storage       virtualization
graphics      multimedia    fonts         xorg          databases
editors       utilities     misc
```

v1 uses both `network` and `networking`, and both `xorg` and `xorg-fonts`.
Pick one of each and normalise on import.

---

## Worked example — qemu, converted from v1

```
Package:          qemu
Version:          10.0.3
Architecture:     x86_64
Section:          virtualization
Description:      Full virtualization solution for Linux with KVM support

Source:           https://download.qemu.org/qemu-10.0.3.tar.xz
Source-SHA256:    <fill in: sha256sum on the cached tarball>

Build-Depends:    glib, pixman, alsa-lib, dtc, libslirp, sdl2,
                  meson, ninja, python3, python3-distlib
Depends:          auto
Provides:         auto

Patches:          0001-python-fixes.patch
Maintainer:       you@blackflag.com.bd

[configure]
mkdir -p build
cd build
../configure --prefix=/opt/hud                    \
             --sysconfdir=/etc                    \
             --localstatedir=/var                 \
             --target-list=x86_64-softmmu         \
             --audio-drv-list=alsa                \
             --disable-pa                         \
             --enable-slirp                       \
             --enable-kvm                         \
             --docdir=/opt/hud/share/doc/qemu-10.0.3

[build]
cd build
make -j$NPROC

[install]
cd build
make DESTDIR=$DESTDIR install

install -vdm755 $DESTDIR/etc/qemu
install -vm644 $SRCDIR/../files/bridge.conf $DESTDIR/etc/qemu/bridge.conf.default

install -vdm755 $DESTDIR/usr/bin
ln -sf /opt/hud/bin/qemu-system-x86_64 $DESTDIR/usr/bin/qemu-system-x86_64
ln -sf /opt/hud/bin/qemu-img           $DESTDIR/usr/bin/qemu-img
ln -sf /opt/hud/bin/qemu-nbd           $DESTDIR/usr/bin/qemu-nbd

[check]
$DESTDIR/opt/hud/bin/qemu-system-x86_64 --version | grep -q "10.0.3"

[postinst]
ldconfig
getent group kvm >/dev/null || groupadd -r kvm
chgrp kvm /opt/hud/libexec/qemu-bridge-helper || true
chmod 4750 /opt/hud/libexec/qemu-bridge-helper || true
[ -f /etc/qemu/bridge.conf ] || cp /etc/qemu/bridge.conf.default /etc/qemu/bridge.conf

[prerm]
rm -f /etc/qemu/bridge.conf.default
```

Changes from v1, and why:

1. Hardcoded target list — `uname -m` at build time is wrong under cross-build.
2. Patch moved into `patches/`, applied by the builder, failure is fatal.
3. `pip3 install distlib` replaced by a `Build-Depends` entry on the package
   you already ship.
4. Environment exports removed — the builder supplies them.
5. `/usr/bin` symlinks moved into `[install]` under `$DESTDIR`, so they appear
   in `FILES` and `hud remove` cleans them up.
6. `bridge.conf` ships as `.default` and is only copied if absent, so upgrades
   stop destroying user edits.
7. `[check]` added.

> The `/usr/bin` symlinks in step 5 are a workaround for `/opt/hud` not being
> on the default library and binary path. They keep libvirt working today. The
> real fix is the FHS migration, and every package needing hand-written
> compatibility symlinks is evidence for it.

---

## Migration from v1

1. Consolidate `sources/definitions/**` into `huddefs/<package>/<package>.huddef`,
   one file per package. Use the copy in `pool/main/<letter>/<name>/` as the
   tiebreaker — that is the one that built the shipped package.
2. Add `Source-SHA256`, computed from the tarballs already in
   `/var/hud-build/cache/`.
3. Move build tools out of `Depends` into `Build-Depends`; set `Depends: auto`.
4. Move inline `wget`-ed patches into `patches/` and commit them.
5. Delete every `|| true` that guards a `patch` or a download.
6. Audit each `[postinst]` against the restrictions above.

Steps 1 and 2 are mechanical and can be scripted. Steps 3 through 6 need
judgement per package, and are good candidates for the fixer agent later —
after the pipeline exists to verify its work.
