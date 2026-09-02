#!/bin/bash
# E4: convert the EASY packages, batches of 20, strictly sequential.
# Resumes from /var/hud-build/convert-state.json.
set -u
SD=/var/hud-build/e4
REPO=/root/github-repo/huddefs
# systemd gives services a minimal PATH (/usr/local/sbin:/usr/local/bin:/usr/sbin
# :/usr/bin) which does NOT include /opt/hud/bin. git lives only at
# /opt/hud/bin/git on this machine, so every automated commit failed with
# "git: command not found" the moment the run moved under systemd — silently,
# because the failure was on the git line and the loop continued. A whole batch
# of conversions sat uncommitted on a machine with failing storage.
export PATH="/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

export GIT_AUTHOR_NAME=montasirrahman GIT_COMMITTER_NAME=montasirrahman
export GIT_AUTHOR_EMAIL=montasirrahmanbd@gmail.com GIT_COMMITTER_EMAIL=montasirrahmanbd@gmail.com

python3 - "$SD" <<'PY'
import json,sys
SD=sys.argv[1]
easy=json.load(open(f"{SD}/easy.json"))
done=[]
try: done=json.load(open("/var/hud-build/convert-state.json"))["done"]
except Exception: pass
todo=[p for p in easy if p not in done]
batches=[todo[i:i+20] for i in range(0,len(todo),20)]
json.dump(batches, open(f"{SD}/batches.json","w"))
print(f"{len(todo)} packages remaining in {len(batches)} batches")
PY

NB=$(python3 -c "import json;print(len(json.load(open('$SD/batches.json'))))")
for i in $(seq 0 $((NB-1))); do
  python3 -c "
import json
b=json.load(open('$SD/batches.json'))[$i]
json.dump(b, open('$SD/batch.json','w'))
print('--- batch $((i+1))/$NB:', len(b), 'packages ---')"
  # systemd-nspawn refuses to start if a previous run left its export mount
  # behind ("Mount point .../unix-export/root exists already, refusing"). That
  # happens when a container is killed rather than exiting. Clear it per batch.
  for m in $(machinectl list --no-legend 2>/dev/null | awk '{print $1}'); do
      machinectl terminate "$m" >/dev/null 2>&1 || true
  done
  umount /run/systemd/nspawn/unix-export/* 2>/dev/null || true
  rm -rf /run/systemd/nspawn/unix-export/* 2>/dev/null || true

  python3 /root/blackflag/scripts/convert-easy.py "$SD/provmap.json" "$SD/batch.json" $((i+1))
  rc=$?
  cd $REPO
  python3 - "$((i+1))" "$NB" <<'PS'
import re,sys
b,nb=sys.argv[1],sys.argv[2]
p="/root/github-repo/huddefs/PROJECT-STATE.md"
s=open(p).read()
s=re.sub(r"\*\*Current phase:\*\*.*?strictly sequential\.(\s*\*\*Batch[^\n]*\*\*)?",
         "**Current phase:** E4 — mechanical v1 -> v2 conversion of the 148 EASY packages,\n"
         "in batches of 20, strictly sequential. "
         f"**Batch {b} of {nb} complete.**", s, count=1, flags=re.S)
open(p,"w").write(s)
PS
  if ! command -v git >/dev/null; then
      echo "FATAL: git not on PATH — refusing to continue and lose commits" >&2
      exit 30
  fi
  git add -A
  if ! git diff --cached --quiet; then
    git commit -q -m "convert batch $((i+1)) of EASY packages to huddef v2

Mechanical conversion: Source-SHA256 from the cached tarball, v1's Depends moved
into Build-Depends, Depends: auto. Built against the shrunk minimal rootfs and
install tested, one package at a time. Results in docs/conversion-progress.md.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
    git push -q origin main && echo "BATCH $((i+1)) PUSHED $(git rev-parse --short HEAD)"
  fi
  if [ $rc -ne 0 ]; then
    echo "E4 HALTED by stop condition (exit $rc) at batch $((i+1))"
    echo E4DONE
    exit $rc
  fi
done
echo "E4 ALL BATCHES COMPLETE"
echo E4DONE
