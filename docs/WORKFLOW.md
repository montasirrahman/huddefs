# BlackFlag build automation — workflow

How a package gets from an upstream release to your `stable` repo without you
touching it.

---

## The rule everything follows

**The pipeline decides. The AI proposes.**

Every stage is a deterministic gate that either passes or fails. The AI worker
exists at exactly one stage — build repair — and its only power is to write a
diff to a branch. It cannot sign, publish, or merge. If you invert this and put
an agent in charge of the pipeline, your repo becomes unpredictable and you will
not find out until something fails to boot.

---

## The chain

```
  upstream release
        │
        ▼
  [1] watcher            cron, no AI          opens a PR with new version + hash
        │
        ▼
  [2] hud-build          clean nspawn root    fails loudly, no silent skips
        │
        ├── fail ──►  [2a] fixer agent   claude -p, max 3 attempts
        │                   │                 ├─ green → back to [2]
        │                   └─ 3 strikes ────►  human queue
        ▼
  [3] hud-scan-deps       ELF + pkg-config + dist-info → Provides / Requires
        │
        ▼
  [4] publish to unstable  hud-repo-manager add
        │
        ▼
  [5] install test        fresh VM from golden snapshot
        │
        ▼
  [6] integration test    libvirt boots a guest
        │
        ▼
  [7] you merge the PR  ──► sign + promote to stable
```

You are asleep for 1 through 6.

---

## Setup, in order

Do not skip ahead. Each step depends on the one before it.

### Step 1 — Get the definitions into git

You currently have 941 `.huddef` files for 245 packages, spread across `old/`,
`old/0`, `old/packages`, `old/updated-packages`, `13 Feb 2026`,
`14 Feb 2026/week1..4`, and more. `qemu-10.0.3.huddef` exists five times in
three genuinely different versions.

Nothing below works until this is fixed, because no automated system can pick
between five copies of a file.

```bash
cd /var/www/hud-repo/sources/definitions
find . -name "*.huddef" -exec md5sum {} \; | sort > /tmp/all.txt
awk '{print $1}' /tmp/all.txt | sort -u | wc -l     # distinct contents
```

For each package name, the copy archived in
`/var/www/hud-repo/pool/main/<letter>/<name>/` is the one that built the shipped
package. Use it as the tiebreaker. Result:

```
huddefs/<package>/<package>.huddef
huddefs/<package>/patches/*.patch
huddefs/<package>/files/*
```

One file per package. The version lives inside it. Git holds the history.

### Step 2 — Build the base rootfs

`hud-build` needs a golden build environment to unpack fresh for every build.

```bash
# from a clean BlackFlag install with hud configured and toolchain present
tar --zstd -cf /var/hud-build/base-rootfs.tar.zst -C / \
    --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/var/hud-build .
```

It must contain: the toolchain, `hud` with `sources.list` pointing at your repo,
binutils (for `readelf`), python3, and `curl`. **Package `wget` and `curl` first
if they aren't in the repo** — right now `wget` is missing from the build server
entirely, which is what silently broke the qemu patch.

Rebuild this rootfs whenever the base system changes. It is an input to every
build, so treat it as versioned.

### Step 3 — Make one package build

```bash
install -m755 hud-build hud-scan-deps /usr/local/bin/
hud-build huddefs/zlib/zlib.huddef
```

Start with `zlib` or `libpng`. Not qemu.

Expect failures. That is the point — v1 definitions rely on things `hud-build`
now refuses to allow: network access mid-build, unhashed sources, `|| true` on
patches, and installs that miss `$DESTDIR`.

### Step 4 — Rebuild all 245

This is the real milestone. Run every package through `hud-build` and collect
the failures.

```bash
for d in huddefs/*/; do
    p=$(basename "$d")
    hud-build "$d/$p.huddef" > /dev/null 2>&1 \
        && echo "OK   $p" || echo "FAIL $p"
done | tee /tmp/rebuild-report.txt
```

Expect a lot of red at first, especially the `python3-*` packages whose
`[install]` sections are missing `--root=$DESTDIR`. `hud-build` catches those
explicitly now instead of shipping a 750-byte empty package.

When this loop is green end to end, you have a reproducible distro. Until then
you have a snapshot.

### Step 5 — The gates

**Golden VM snapshot.** A clean BlackFlag install with `hud` and nothing else.
Every test restores from it, tests, and is destroyed. Your current
`hud-client` at 172.19.1.9 becomes the template, and then you stop logging into
it.

```bash
# sketch
virsh snapshot-revert blackflag-test golden --running
ssh test-vm "hud update && hud install -y $PKG" || exit 1
ssh test-vm "$SMOKE_CMD"                        || exit 1
```

**Split the repo.** `unstable` and `stable` as separate endpoints. Your
`sources.list` format already carries a release field:

```
hud http://172.19.1.7/hud-repo stable main
```

The client currently ignores it and fetches `$url/packages.list` directly. Make
it fetch `$url/$release/packages.list` and the split costs nothing else.

### Step 6 — CI

Gitea with Actions, self-hosted runner on the build server, is the least work
for one person on an internal network. A `.gitea/workflows/build.yml` that runs
`hud-build` on changed huddefs, then the install and integration tests, then
attaches the result to the PR.

Keep the runner on the build server. Do not give it the signing key.

### Step 7 — The watcher

Poll upstream, diff against `Version:` in each huddef, open a PR with the new
version and a recomputed `Source-SHA256`. Roughly 200 lines of Python against
release-monitoring.org (Anitya) and the GitHub releases API. **No AI.**

This is the highest value-per-effort piece in the whole system. Run it for a
month before adding anything smarter.

### Step 8 — The fixer agent

Only now.

```bash
claude -p "The build for $PKG failed. Read logs/$PKG.log, fix the huddef, commit." \
  --allowedTools "Read,Edit,Bash(hud-build:*),Bash(git:*)" \
  --max-turns 8 \
  --output-format json
```

Ship `CLAUDE.md` in the huddefs repo so it knows the format rules. Add a
`PreToolUse` hook that blocks any write to signing keys, to `main`, or to
`/var/www/hud-repo/` — `CLAUDE.md` is persuasion, a hook is enforcement.

Three attempts, then the PR is labelled `needs-human` and left alone.

Run this on an API key with a spend cap, not your Pro subscription. Pro is
session- and week-limited and is meant for your interactive work; an unattended
rebuild cascade will exhaust it in an afternoon and lock you out mid-task.

---

## Timeline

| Steps | What | Rough effort |
|---|---|---|
| 1–2 | git consolidation, base rootfs | 1–2 weeks |
| 3–4 | all 245 rebuild clean | 6–10 weeks |
| 5–6 | gates and CI | 3–4 weeks |
| 7 | watcher | 1 week |
| 8 | fixer agent | ongoing |

Steps 1 through 4 contain no AI at all, and they are most of the work. That
ordering is deliberate: an agent cannot automate a process you cannot yet run
reliably by hand. It will produce plausible-looking definitions that fail in
ways you don't notice until something won't boot.

---

## Notes on the scripts

`hud-build` and `hud-scan-deps` are written against the format I saw in your
audit, but I could not run them on BlackFlag. Expect to adjust:

- **nspawn flags.** `--private-network` needs `CONFIG_NET_NS` in your kernel.
  Check with `systemd-nspawn --version` and a trial run.
- **`hud install -y`.** I assumed a `-y` flag. If the client doesn't have one,
  add it or drive it differently.
- **Base rootfs format.** I used zstd; switch to gzip if `tar --zstd` isn't
  available.
- **`hud-scan-deps` on ELF-heavy packages** is slow, since it forks `readelf`
  per file. Fine for now; batch it later if 245 packages take too long.

`hud-build` deliberately has **no insecure fallback** on download. Your client's
`wget --no-check-certificate` / `curl -k` chain is how an attacker gets root on
every machine, and I did not want to reproduce that pattern on the build side.
