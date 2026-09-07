# Roadmap to an appliance

Where this is, what stands between it and a KubeVirt appliance, and in what
order. Written 2026-09-07, after E4–E9, G2, G3 and G4.

The hard gate in `PROJECT-STATE.md` has four conditions. **One is met.** This
document is mostly about why the other three are further away than they look,
and about a fifth condition that was not on the list and should have been.

---

## Where the four gates stand

| Gate | State |
|---|---|
| 1. G1 passes — all 245 rebuild from scratch | **Not started, and cannot be honest yet.** See below |
| 2. G2 exists — the graph answers exactly | **Met.** `scripts/hud-graph`, equality joins, no `LIKE` |
| 3. Client verifies SHA256; packages signed | **Not started.** The client still falls back to `curl -k` |
| 4. FHS vs `/opt/hud` decided | **Not decided, and now blocking other work** |

### Gate 2 is met, with one caveat worth stating

`hud-graph` answers `deps`, `rdeps`, `why`, `orphans` and `missing` against a
capability table, exactly. But 263 of its edges are still recorded as package
names rather than capabilities, because those packages were published before
huddef v2 and their metadata has no `Requires:` field. The graph resolves both
kinds and says which is which; the name edges disappear as packages are rebuilt.
**So gate 2 is met in mechanism and will only be met in substance after G1.**

### Gate 1 is blocked on something that was not on anyone's list

**The build rootfs is not what it claims to be.** `docs/rootfs-audit.md` has the
detail: 2,226 dangling symlinks, 242 registered packages where there should be
nine, 5,002 leftover files. A G1 run against it would report 245 green and prove
nothing, because a package can link against a half-deleted dependency, or find a
`.pc` file that points at a library that is gone and fail in a way that gets
blamed on its source.

Regenerating it — installing the nine bootstrap packages onto a clean base
rather than deleting files from a populated one — is **the single highest-value
piece of work left**, and it is a prerequisite for G1 rather than part of it.

G1 is also blocked on a genuine bootstrap cycle, `cmake → curl → brotli → cmake`
(`docs/build-order.md`), which holds 25 of the 246 packages and was invisible
until this week.

### Gate 4 has stopped being theoretical

The FHS question was framed as a decision about Kubernetes. It is now blocking
**ten E7 packages and G5**: `libvirt`, `firewalld`, `networkmanager` and the
rest write config, systemd units and executables outside `/opt/hud` from
`[postinst]`, where nothing tracks them. `docs/needs-human.md` asks it at the
small scale — may a hud package own a file outside `/opt/hud`, and which
directories — and the answer there should be consistent with whatever is decided
at the large scale.

**Deciding this early costs nothing and unblocks work now.**

---

## The fifth condition that should have been on the list

**A package must be provably non-empty.**

Between them, 68 packages published successfully while containing nothing: 66
`python3-*` whose pip install lacked `--root=$DESTDIR`, `docbook-xsl` whose
`[install]` wrote absolute paths, and `meson`, which ships two shell completion
files and no program. Every one built, install-tested and published green.

Emptiness is not an error condition in this pipeline — it is a normal outcome
that nothing checks. The E5/E6 driver now refuses to publish an archive holding
only metadata, and `docs/empty-package-sweep.md` has a sweep to run against all
245. **G1 should run that sweep at the end and fail if it finds anything.**

More generally, three of this session's worst defects share a shape:

- `convert-state.json` recorded intent rather than artifacts — 18 conversions
  silently lost
- `repo_names()` returned empty on failure rather than raising — 55 dependency
  lists silently deleted
- a package with no payload is indistinguishable from a package with one, to
  every check in the pipeline

**Every gate from here should verify the artifact, never the process that
produced it.** G4 was built that way deliberately — it reads console output for
a marker rather than trusting qemu's exit code — and it is the reason it found
the rootfs problem instead of passing quietly.

---

## Order of work

1. **Regenerate the build rootfs.** Everything below is unverifiable until this
   is done. Not large; it is `hud install` of nine packages onto a clean base.
2. **Answer the three questions in `docs/needs-human.md`.** They are cheap to
   answer and each unblocks a phase:
   - package `flit_core`, `packaging`, `calver` → unblocks 33 Python packages
   - decide who owns `/etc` → unblocks 10 E7 packages, and G5
   - cut the `cmake → curl → brotli` cycle → unblocks a genuine G1
3. **Finish E5–E9** against the regenerated rootfs. Every one of those phases
   has been validated against a root that lies.
4. **G1.** All 245, dependency-ordered, unattended, with the emptiness sweep as
   an exit check.
5. **Rebuild the capability graph.** `hud-graph stats` should reach zero empty
   packages and zero name-kind edges. Those two numbers are the cheapest
   summary of whether G1 really worked.
6. **G5.** Nested KVM is proven (`docs/g5-status.md`); this waits on libvirt
   from step 2.
7. **Signing and SHA256 verification.** The three D8 branches are still
   unmerged and nothing is deployed. This is the last gate before the appliance
   work and the one with the widest blast radius: the client currently extracts
   as root without verifying anything, over plain HTTP.
8. **Then, and only then, KubeVirt.**

---

## Two standing risks that do not go away

**bf-repo's disk is USB-attached and fails under sustained write load.** Three
failures, one lost write. Building stays on bf-build. Anything that writes
multiple gigabytes to bf-repo — including building a G4 image — should be done
once and deliberately, not in a loop.

**The 251 shipped packages are not reliably rebuildable.** `cmake` does not
compile under GCC 15.2 today. The pool is a backup of binaries that in some
cases cannot be recreated from source, which is why nothing in this work has
ever written to `/var/www/hud-repo/`, and why the staging repo exists.
