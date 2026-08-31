# BlackFlag infrastructure

Context for working on the BlackFlag Linux build system. Read this before
running anything against the servers.

## Machines

Both are reached over SSH. Aliases are configured in `~/.ssh/config`; always use
the alias, never the raw IP. As of 2026-08-31 bf-repo's hostname matches its
alias; bf-build has not been renamed yet because it is not reachable over SSH
from bf-repo (see below).

| Alias | Hostname | IP | Former hostname | Role |
|---|---|---|---|---|
| `bf-repo` | `bf-repo` | 172.19.1.7 | `hud-server-local` | Package repository, nginx, git |
| `bf-build` | `hud-test1` *(rename pending)* | 172.19.1.11 | `hud-test1` | Builds packages, runs test containers |

Both former hostnames are kept as aliases in `/etc/hosts` **on bf-repo**, so
anything still referring to `hud-server-local` or `hud-test1` continues to
resolve there. nginx serves the repo on `server_name _` and never depended on
either name, so the rename did not affect HTTP.

**Still outstanding:** bf-build is still named `hud-test1` and its `/etc/hosts`
is unchanged. bf-repo holds no SSH key that bf-build accepts — trust currently
runs one way only, bf-build to bf-repo.

Both run BlackFlag Linux 1.0.0 (Fajr), a Linux From Scratch derivative with
systemd 257.8. There is no docker, podman, or containerd — use
`systemd-nspawn` for isolation.

Run commands with `ssh bf-repo "..."`. Do not install Claude Code on the
servers; it runs from here so that a broken server is still reachable.

---

## bf-repo — treat as precious

This machine holds work that exists nowhere else.

```
/var/www/hud-repo/
├── packages.list                    generated index, served over HTTP
├── packages.db                      sqlite, source of truth for the repo
├── pool/main/<letter>/<name>/       built .hud packages + archived .huddef
└── sources/definitions/             941 .huddef files, no version control
```

### Do not, without asking first

- Delete or modify anything under `/var/www/hud-repo/sources/definitions/`
- Delete anything from `pool/`
- Write to `packages.db` or `packages.list` directly — only
  `hud-repo-manager` writes those
- Restart nginx during a build
- Run `hud-repo-manager remove`

Reading anything here is fine. Prefer read-only work on this machine; copy
files to `bf-build` or to this laptop when you need to modify them.

### The archived huddef is the tiebreaker

`hud-repo-manager add` copies the `.huddef` into the pool next to the `.hud` it
produced. So `pool/main/q/qemu/qemu-10.0.3.huddef` is the definition that built
the shipped package. When `sources/definitions/` has five conflicting copies,
the pool copy is the evidence for which one is real.

---

## bf-build — disposable

Where builds and tests run. Nothing here is precious; it can be rebuilt from
the base rootfs. Work freely.

```
/var/hud-build/
├── cache/                  upstream source tarballs
├── output/                 freshly built .hud files
├── logs/                   build logs
├── base-rootfs.tar.zst     golden build environment (does not exist yet)
└── work/                   scratch, wiped per build
```

Two consumers of the same rootfs:

- **Building** — `hud-build` unpacks it, installs `Build-Depends`, builds with
  `--private-network`, produces a `.hud`
- **Testing** — unpack it, `hud install` the new package, smoke test, destroy

---

## Current state, honestly

Known problems, so you don't rediscover them:

1. **941 `.huddef` files for 245 packages.** Spread across `old/`, `old/0`,
   `old/packages`, `old/updated-packages`, `13 Feb 2026`,
   `14 Feb 2026/week1..4`, and others. `qemu-10.0.3.huddef` exists five times
   in three genuinely different versions. Consolidating this into
   `huddefs/<package>/<package>.huddef` is task one.

2. **No build tooling exists.** `/var/hud-build/` has only `cache/` and
   `output/`. Packages were built by hand. `scripts/hud-build` in this repo is
   new and unproven.

3. **`wget` is missing** from bf-repo and from all 245 packages. This silently
   broke the qemu patch: `wget ... || true` failed, `patch ... || true` failed,
   the build reported success, and the shipped qemu is probably unpatched.
   `curl` may be present — check.

4. **~60 `python3-*` packages are ~750 bytes** and contain no payload. Their
   `[install]` sections most likely miss `--root=$DESTDIR`, so pip installed
   into the build server instead of the staging directory. `python3-distlib`
   at 662KiB is the correct reference. This also left malformed dist-info in
   `/opt/hud/lib/python3.13/site-packages`, which currently crashes every
   `pip3 install` on bf-repo.

5. **The client does not verify SHA256** before extracting as root, has no
   package signing, and falls back to `wget --no-check-certificate` and
   `curl -k`. The repo is served over plain HTTP. Not yet fixed.

6. **`Depends:` mixes build and runtime.** `dav1d` depends on `meson,ninja,nasm`.
   Fixed by `Depends: auto` in huddef v2.

---

## Rules

1. **Back up before destructive work.** A dated tarball of
   `/var/www/hud-repo/sources/` exists on the laptop. Verify it covers what
   you're about to touch.

2. **No signing keys on either machine.** Signing and promotion to `stable` are
   manual steps performed by the maintainer.

3. **Never add an insecure download fallback.** No `--no-check-certificate`, no
   `curl -k`. If a fetch fails, fail.

4. **Never write `|| true` after `patch` or a download.** That pattern is why
   the shipped qemu is broken.

5. **Prefer copy-then-modify.** Pull files from bf-repo to bf-build or to the
   laptop, work there, and propose the result. Don't edit in place on bf-repo.

6. **Report what you ran.** These machines have no audit trail. Say which
   commands executed on which host.

---

## Useful commands

```bash
ssh bf-repo  "hud-repo-manager list"          # what is published
ssh bf-repo  "hud-repo-manager show qemu"     # one package, all versions
ssh bf-build "ls /var/hud-build/output/"      # freshly built
ssh bf-build "systemd-nspawn --version"       # isolation available?
ssh bf-build "ls -l /dev/kvm"                 # can we boot guests here?
```
