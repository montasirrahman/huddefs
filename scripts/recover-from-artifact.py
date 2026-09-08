"""Restore v2 definitions that were converted in place and then lost.

convert-python.py rewrites <pkg>.huddef in the working tree, and run-queue.sh
only commits at the END of a run. A `git merge --ff-only` that cannot
fast-forward resets the worktree to HEAD, which threw away every conversion the
in-flight run had made but not yet committed.

hud-build copies the definition it actually used into the package, at
opt/hud/share/hud/info/<pkg>/<pkg>.huddef. That copy is evidence, not a
reconstruction: it is the file that produced the shipped bits. Recover from it
rather than re-running the converter, which would have to re-derive the PEP 517
backend and could legitimately produce something different.
"""
import glob, os, subprocess, sys, tarfile

REPO = "/root/github-repo/huddefs/huddefs"
POOL = "/var/www/hud-unstable/pool/main"

def embedded(pkg):
    hits = glob.glob(f"{POOL}/{pkg[0]}/{pkg}/{pkg}-*.hud")
    if not hits:
        return None
    art = max(hits, key=os.path.getmtime)
    member = f"./opt/hud/share/hud/info/{pkg}/{pkg}.huddef"
    try:
        with tarfile.open(art) as t:
            fh = t.extractfile(member)
            return fh.read().decode("utf-8", "replace") if fh else None
    except (KeyError, tarfile.TarError):
        return None

def is_v2(text):
    return "Source-SHA256:" in text and any(
        l.startswith("Build-Depends:") for l in text.splitlines())

out = subprocess.run(["grep", "-rL", "Source-SHA256:"] +
                     glob.glob(f"{REPO}/*/*.huddef"),
                     capture_output=True, text=True)
v1 = sorted(os.path.basename(p)[:-7] for p in out.stdout.split())

restored, nopkg, stillv1 = [], [], []
for pkg in v1:
    text = embedded(pkg)
    if text is None:
        nopkg.append(pkg); continue
    if not is_v2(text):
        stillv1.append(pkg); continue
    open(f"{REPO}/{pkg}/{pkg}.huddef", "w").write(text)
    restored.append(pkg)

print(f"restored {len(restored)}: {' '.join(restored)}\n")
print(f"no package in unstable ({len(nopkg)}): {' '.join(nopkg)}\n")
print(f"shipped package was itself built from v1 ({len(stillv1)}): {' '.join(stillv1)}")
