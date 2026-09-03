# Migrating the build workload to bf-build

## Why

bf-repo's VDI is on **F:, a TOSHIBA EXTERNAL_USB disk**. The drive is healthy;
the USB link drops under sustained heavy write load, resets, and loses writes
already in flight. Three failures resulted, on 2026-09-01, 09-02 and 09-03, the
last one losing a write. At roughly 20 GB of I/O per package, the conversion was
doing exactly what breaks USB attachment.

bf-build's VDI is on **Disk 0, the internal KIOXIA NVMe SSD** — 224 MB/s
measured, against bf-repo's 30–43.

|  | bf-build | bf-repo |
|---|---|---|
| storage | internal NVMe | **USB external** |
| throughput | 224 MB/s | 30–43 MB/s |
| overlayfs | **present** | `CONFIG_OVERLAY_FS` unset |
| `/dev/kvm` | absent | present |
| I/O failures | none | **three in three days** |

## What moves, and what does not

**Moves:** building, testing, the conversion run.

**Stays on bf-repo:** nginx, `packages.db`, `pool/`, publishing, and G4/G5.
Serving an index over HTTP is light intermittent I/O that USB handles fine — it
is sustained multi-gigabyte writes that break the link. G4 and G5 stay because
bf-repo has the only `/dev/kvm`.

## Prerequisites

- [ ] bf-build resized to 4 cores / 8 GB
- [ ] room on the internal SSD for ~10 GB of rootfs images, cache and scratch
- [ ] offline `fsck` completed on bf-repo

## Steps

### 1. Verify bf-build

```bash
ssh bf-build 'nproc; free -g | head -2; df -h /; grep -c overlay /proc/filesystems'
ssh bf-build 'command -v git; command -v systemd-nspawn; command -v hud'
```

**Check where `git` lives.** On bf-repo it is only at `/opt/hud/bin/git`, which
is not on systemd's default service PATH — that silently failed every automated
commit for a whole batch. If the same is true on bf-build, the driver's explicit
`PATH` export already covers it, but confirm rather than assume.

### 2. Transfer

```bash
# scripts come from git, not scp
ssh bf-build 'mkdir -p /root/github-repo && cd /root/github-repo && \
              git clone git@github.com:montasirrahman/huddefs.git'

# rootfs images (1.1 G + 2.7 G) and the source cache (1.2 G, 361 tarballs)
ssh bf-build 'mkdir -p /var/hud-build/{cache,output,logs,work} /var/hud-test'
scp /var/hud-build/base-rootfs-minimal.tar.zst bf-build:/var/hud-build/
scp /var/hud-build/base-rootfs.tar.zst         bf-build:/var/hud-build/
rsync -a /var/hud-build/cache/ bf-build:/var/hud-build/cache/

# the resume point — this exists nowhere else
scp /var/hud-build/convert-state.json  bf-build:/var/hud-build/
scp /var/hud-build/dropped-deps.json   bf-build:/var/hud-build/
scp -r /var/hud-build/e4               bf-build:/var/hud-build/
```

### 3. Configure

```bash
# Build-Depends resolve from bf-repo's repo over HTTP — light I/O, stays put
ssh bf-build 'cat /etc/hud/sources.list'   # must be: hud http://172.19.1.7/hud-repo stable main
ssh bf-build 'install -m755 /root/github-repo/huddefs/scripts/hud-{build,scan-deps,test} /usr/local/bin/'
ssh bf-build 'install -m644 /root/github-repo/huddefs/scripts/hud-build.conf /etc/hud-build.conf'
```

### 4. Regenerate the minimal rootfs on bf-build

The current image was built **from bf-repo**, so it carries bf-repo's base
system. Both machines run BlackFlag 1.0.0 so it will work, but G1's claim to be
"reproducible from scratch" is weaker if the image came from somewhere else.
Regenerate once builds are living there:

```bash
ssh bf-build 'bash /root/github-repo/huddefs/scripts/build-base-rootfs.sh minimal'
```

### 5. Implement `--volatile=overlay`

**This is the payoff, and it was impossible on bf-repo.** bf-build's kernel has
overlayfs, so `hud-build` and `hud-test` can mount an overlay over one
pre-extracted tree instead of unpacking 3.3 GB per package.

Note the constraint discovered during F5: `--volatile=overlay` uses a **tmpfs**
upper layer and discards everything when the container exits. Both scripts run
several `nspawn` invocations per package and must retrieve the built artifact, so
they need either a disk-backed overlay (`mount -t overlay` with `upperdir` on
disk) or bind mounts for `/build` and `/dest`. The disk-backed overlay is the
better fit — it survives between invocations and costs nothing on NVMe.

`scripts/prepare-roots.sh` already extracts the images to
`/var/hud-build/roots/<name>` idempotently, which is what an overlay mounts over.

Expected effect: per-package cost drops from ~300 s, most of it I/O, to
compilation time alone.

### 6. Resume

```bash
ssh bf-build 'systemd-run --unit=e4run --property=Type=simple \
                /bin/bash /var/hud-build/e4/e4.sh'
```

Use the **default** `KillMode`. `KillMode=process` leaves the Python child
running after `systemctl stop`, which produced three concurrent builds and
orphaned containers that blocked every subsequent build.

## Verifying the migration worked

- one build at a time: `ps -eo args | grep -c '[/]usr/local/bin/hud-build'`
- per-package time well under the ~300 s bf-repo took
- `journalctl -k --since '15 minutes ago' | grep -i 'I/O error'` stays empty
- batches commit and push on their own

## After migration

`docs/WORKFLOW.md` and `PROJECT-STATE.md` both describe bf-repo as the interim
build host. Update them once this is done, so the next person is not sent to the
wrong machine.


---

## Migration executed 2026-09-03

Completed and verified. bf-build was resized to **4 cores / 5.8 GB**.

### Transferred

| What | Result |
|---|---|
| `huddefs` repo (626 files, full history) | HEAD `cb61753`, clean, origin intact |
| `convert-state.json` | 87 packages recorded — **existed nowhere else** |
| `dropped-deps.json` | transferred |
| `e4/` driver and supervisor | transferred |
| `base-rootfs-minimal.tar.zst` (1.1 G) | sha256 `2d79ecd7c35bac70` — **identical** |
| source cache | 362 tarballs, zlib sha `9a93b2b7dfdac77c` — **identical** |

`rsync` is not installed on bf-repo, so transfers used `tar` over ssh.

### Installed on bf-build

`hud-build`, `hud-scan-deps`, `hud-test`, `prepare-roots.sh` into
`/usr/local/bin`; `hud-build.conf` into `/etc`; the converters into
`/root/blackflag/scripts`. All prerequisites present.

**`git` was missing** and was installed from the repo (2.50.1). Note it landed at
`/opt/hud/bin/git` — the same location that is off systemd's default service PATH
on bf-repo and silently broke a batch of commits. The driver's explicit `PATH`
export covers it, but it is the same trap.

### Verified by building

```
zlib   build 27s   test 18s   both green
       Provides: libz.so.1, pkgconfig(zlib)   Requires: libc.so.6
```

|  | bf-repo (USB) | bf-build (NVMe) |
|---|---|---|
| zlib build | 118–150 s | **27 s** |
| storage | 30–43 MB/s | 224 MB/s |

**A 5x improvement before overlayfs is implemented at all**, purely from moving
off the USB-attached disk. The remaining 27 s is still mostly the 3.3 GB rootfs
extract, which overlayfs removes.

### Outstanding

**bf-build cannot push to GitHub.** Its key
(`ssh-ed25519 AAAA…zQwl root@hud-test1`) is not on the account:

```
git@github.com: Permission denied (publickey)
```

Batch commits will succeed locally and fail to push. Fix by adding that public
key at github.com → Settings → SSH and GPG keys. Until then, pushes must be made
by pulling from bf-build to bf-repo, or by hand.

---

## Overlay build roots implemented 2026-09-03

The F5 design, finally possible. `hud-build` and `hud-test` now mount an overlay
over the pre-extracted tree at `/var/hud-build/roots/<name>` instead of unpacking
3.3 GB per package.

### Measured

| | bf-repo (USB, extract) | bf-build (NVMe, overlay) |
|---|---|---|
| `zlib` build | 118–150 s | **5 s** |
| `zlib` install test | ~120 s | **6 s** |
| rootfs extract (one-time) | 103 s | 16 s |

Roughly **25x**. Two independent gains: the USB-to-NVMe move alone took the build
from ~150 s to 27 s, and the overlay took it from 27 s to 5 s by removing the
per-package extract entirely.

### The upper layer is on disk, not tmpfs

`--volatile=overlay` was rejected. It uses a tmpfs upper and discards everything
when the container exits, but `hud-build` runs **two** separate nspawn
invocations — the Build-Depends install, then the network-isolated build — and
then has to retrieve the artifact from `/dest`. A tmpfs upper would lose the
installed dependencies between the two, and then the package itself. `hud-test`
runs five invocations and has the same problem.

An explicit `mount -t overlay` with `upperdir` on disk survives between
invocations and costs nothing on NVMe.

### Cleanup unmounts before deleting

This is the dangerous part and it is handled explicitly:

```bash
cleanup() {
    if mountpoint -q "$ROOT"; then umount "$ROOT" || umount -l "$ROOT"; fi
    if mountpoint -q "$ROOT"; then
        warn "still mounted; leaving $WORK rather than deleting through it"
        return
    fi
    rm -rf "$WORK"
}
```

If `$ROOT` were still mounted, `rm -rf` would delete **through** the overlay into
the pristine lower tree that every build depends on. The script refuses to delete
a mountpoint and leaves the directory instead.

### Isolation verified

A 62,289-file manifest of the pristine tree was taken before and after a real
build:

```
RESULT: pristine tree UNCHANGED — overlay isolation verified
```

This is the test the `cp -al` hardlink farm failed on bf-repo, where a single
`hud install` rewrote `/etc/profile.d/hud-env.sh` through a shared inode. The
overlay does what the hardlink farm only appeared to.

### Fallback retained

Where the kernel has no overlayfs — bf-repo — both scripts fall back to
extracting the image, so they still work there. The fallback is not dead code.
