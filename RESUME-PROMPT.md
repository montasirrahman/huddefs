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

THIS IS A PRODUCTION DISTRIBUTION. Do not skip a package, and do not work around
a failure. Find the ROOT CAUSE and fix it, then follow the dependency chain down
until everything the package needs exists and is declared. If something it needs
is not packaged, package it. A green build is not evidence — check that the
artifact has a payload, that its libraries resolve, and that its declared
dependencies actually install.

STATE: E4, G3, E8, E9, G2, G4 done. Every structural blocker is CLOSED:
  - Depends: auto now resolves to package names (resolve-capabilities.py);
    Requires keeps capabilities. Verified: hud install pulls real dependencies.
  - flit_core, packaging, calver packaged -> all 66 python3-* are buildable.
  - File-ownership policy decided: docs/file-ownership-policy.md.
  - The cmake -> curl -> brotli cycle is broken. 250 packages, 250 ordered,
    0 cycles, and no Build-Depends names anything unpackaged.
  - No build section reaches the network. jinja2/markupsafe/pyxattr packaged.
  - G5's two halves are proven separately; scripts/g5-gate.sh waits on libvirt.

QUEUE, in order:
  1. Watch the build queue drain. One unit on bf-build, dependency-ordered,
     with a supervisor writing /var/hud-build/e5/heartbeat.log every 10 min.
       ssh bf-build 'systemctl is-active queue; tail -3 /var/hud-build/e5/heartbeat.log'
       bash scripts/status.sh          # one screen of everything
     Fix each failure at the ROOT CAUSE and re-queue it. Five definitions have
     already turned out to be incapable of building what they published.
  2. G1 — scripts/g1-rebuild.sh. Full rebuild against roots/minimal-clean, four
     exit gates that can each fail it: every package has a payload, the lint is
     clean, no capability Depends remain, nothing failed to build. It also does
     the cmake second pass against system curl.
  3. G5 — scripts/g5-gate.sh, once libvirt is built and published.
  4. Then the hard gate's remaining items: SHA256 verification and signing in
     the client, and the FHS vs /opt/hud decision.
  5. docs/roadmap-to-appliance.md, then stop.

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
