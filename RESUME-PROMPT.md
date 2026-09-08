# Paste this into a new session

Copy everything between the fences.

```
Read these in order before doing anything:
  /root/github-repo/huddefs/PROJECT-STATE.md      <- status, incidents, precedents
  /root/github-repo/huddefs/RESUME-HERE.md        <- orientation and the queue
  /root/github-repo/huddefs/CLAUDE.md             <- rules for editing definitions
  /root/github-repo/huddefs/docs/needs-human.md   <- three blocking decisions

You are on bf-repo. BUILDING RUNS ON bf-build over ssh — never on bf-repo, whose
USB-attached disk has failed three times under build load and lost a write.
bf-repo keeps the repo, nginx, publishing, and G4/G5 (it has the only /dev/kvm).

WORK NON-STOP. Do not stop to ask for confirmation. Push after every batch.

STATE: E4, G3, E8, E9, G2 and G4 are done. E5/E6 is 33 of 66. E7 is 9 of 10
mechanical rebuilt. 45 packages published to /var/www/hud-unstable. The build
driver's failure list is empty. G5 step 0 (nested KVM) is proven.

QUEUE, in order:
  1. BLOCKING — docs/needs-human.md, "Depends: auto produces something the
     deployed client cannot use". Every v2-rebuilt package publishes capability
     strings (libxml2.so.16) that the client looks up as package NAMES, warns
     about, and skips; hud install then exits 0. All 45 published packages
     install without their runtime dependencies. Fix: map capabilities back to
     package names in hud-build before writing Depends, keeping Requires as
     capabilities. scripts/build-soname-map.sh already produces the mapping.
  2. Package flit_core, packaging and calver — they block 33 of the 66 empty
     python3-* packages. All three build with setuptools alone.
  3. Decide who owns files outside /opt/hud — blocks E7's remaining 10 and, via
     libvirt, G5. docs/needs-human.md has the inventory and a recommendation.
  4. The six still failing on BOTH build roots: ncurses, libxslt, libvorbis,
     libxcb, libXt, lcms2. The rootfs is ruled out; each needs its own
     diagnosis. The last four turned out to be a missing Build-Depends, a wrong
     Source, and two headers/paths — expect the same shape.
  5. G1 — full rebuild, dependency-ordered, against roots/minimal-clean.
     scripts/build-order.py gives the order and names the cmake -> curl ->
     brotli cycle. Run docs/empty-package-sweep.md at the end and fail on a hit.
  6. G5 — the VM starts libvirtd and boots a guest. Waits on item 3.
  7. docs/roadmap-to-appliance.md, then stop.

HOW TO WORK HERE
  - Verify the ARTIFACT, never the record of producing it. Seven of eight hud
    client commands exit 0 on failure. A green build is not evidence.
  - scripts/lint-huddefs.py enforces CLAUDE.md's hard rules.
    scripts/verify-sources.py checks every Source-SHA256 against the cache.
    scripts/hud-graph stats is the cheapest summary of overall health.
  - bf-build cannot push to GitHub. Collect its commits from bf-repo:
      git remote add bfbuild ssh://root@bf-build/root/github-repo/huddefs
      git config remote.bfbuild.uploadpack /opt/hud/bin/git-upload-pack
      git fetch bfbuild main && git merge bfbuild/main && git push origin main
    and the reverse on bf-build with remote bfrepo -> ssh://root@172.19.1.7/...
  - git lives only at /opt/hud/bin/git. Always export PATH in a systemd unit.
  - Never hardcode a build unit name; it changes every run.

NEVER, regardless of progress:
  - write under /var/www/hud-repo/, or run hud-repo-manager add/remove there
  - deploy hud or hud-repo-manager to /usr/local/bin
  - merge the three D8 branches, or touch signing keys
  Publishing to /var/www/hud-unstable/ is fine and is how this work proceeds.

HALT AND REPORT only for: I/O errors or a filesystem going read-only, or /var
above 120 G on either machine.
```
