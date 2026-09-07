#!/usr/bin/env python3
"""
E5/E6 driver — fix the empty python3-* packages, one at a time, in the order
computed from their own sources (plan2.json), and publish each to unstable
before the next one starts.

Two things this does that the E4 driver did not, both because of what E4 cost:

1. It records a package as done only after the artifact is PUBLISHED, not after
   the build reports success. E4's state file recorded intent, so a batch whose
   commit was lost still counted as converted and 18 definitions silently stayed
   v1 for four days.

2. It asserts the package has a payload. The entire defect being fixed here is
   packages that build, test and publish perfectly while containing nothing but
   metadata — a green build is exactly what the broken ones already produce, so
   a green build is not evidence of a fix. `payload_ok` requires real files
   under site-packages that are not .dist-info bookkeeping.
"""
import json, os, re, shutil, subprocess, sys, tarfile, time

REPO   = "/root/github-repo/huddefs"
H      = f"{REPO}/huddefs"
OUT    = "/var/hud-build/output"
STATE  = "/var/hud-build/e5-state.json"
BFREPO = "root@172.19.1.7"
INBOX  = "/var/hud-build/incoming"
WRAP   = "/var/hud-build/bin/hud-unstable"
SONAME = "/var/hud-build/sonamemap.json"


def sh(cmd, timeout=7200):
    """Run a command, returning (rc, output). A timeout is a result, not a crash.

    subprocess.run raises TimeoutExpired, and letting that propagate killed the
    whole run: nodejs exceeded two hours, the exception escaped one(), and
    openldap, openssl, p11-kit and util-linux were never attempted. A driver
    that processes a list must record a slow package as failed and carry on —
    the alternative is that one long build silently cancels everything behind
    it.
    """
    try:
        p = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                           timeout=timeout, errors="replace")
        return p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        out = ""
        for part in (e.stdout, e.stderr):
            if part:
                out += part if isinstance(part, str) else part.decode("utf-8", "replace")
        return 124, out + f"\n[timed out after {timeout}s]"


def load_state():
    try:
        return json.load(open(STATE))
    except Exception:
        return {"published": [], "failed": {}}


def save_state(s):
    tmp = STATE + ".tmp"
    json.dump(s, open(tmp, "w"), indent=1)
    os.replace(tmp, STATE)


def declared_depends(art):
    """Packages that provide the sonames this artifact links against.

    `Depends: auto` records capabilities — sonames and python3dist() names — not
    package names, so the install test starts in a root where nothing provides
    them and every compiled extension shows up as an unresolved library.
    python3-lxml built perfectly and was reported FAIL for exactly that.
    Map the sonames back to packages and install those first.
    """
    try:
        smap = json.load(open(SONAME))
    except Exception:
        return []
    try:
        with tarfile.open(art) as t:
            meta = [m for m in t.getmembers()
                    if m.name.endswith("/PACKAGE") and "/share/hud/info/" in m.name]
            if not meta:
                return []
            text = t.extractfile(meta[0]).read().decode("utf-8", "replace")
    except Exception:
        return []
    pkgs = set()

    m = re.search(r"^Requires:\s*(.*)$", text, re.M)
    if m:
        for cap in (c.strip() for c in m.group(1).split(",")):
            # libc.so.6 and friends come from the base system, not a package
            if cap in smap:
                pkgs.add(smap[cap])

    # Depends may be an explicit package list rather than derived capabilities.
    # The v2 spec allows that exactly when auto-detection cannot see the
    # dependency — "a binary invoked by exec" — which is docbook-xsl's case: its
    # postinst runs xmlcatalog, from libxml2. Reading only Requires meant the
    # one dependency that was declared BECAUSE auto could not find it was the
    # one the test root did not install, and the install test failed at postinst.
    d = re.search(r"^Depends:\s*(.*)$", text, re.M)
    if d:
        for name in (x.strip() for x in d.group(1).split(",")):
            if name and name != "auto" and "(" not in name and ".so" not in name:
                pkgs.add(name)
    return sorted(pkgs)


def artifact(pkg):
    """Newest .hud in output/ for this package name."""
    best, bestm = None, -1
    for f in os.listdir(OUT):
        if not f.endswith(".hud"):
            continue
        if re.match(rf"^{re.escape(pkg)}-\d", f):
            m = os.path.getmtime(os.path.join(OUT, f))
            if m > bestm:
                best, bestm = os.path.join(OUT, f), m
    return best


def payload_ok(art):
    """Real installed files, not just metadata.

    The broken packages are ~750 bytes and contain only share/hud/info and an
    empty dist-info. A fixed one has modules under site-packages, or scripts in
    bin, or data under share that is not hud's own bookkeeping.
    """
    try:
        with tarfile.open(art) as t:
            names = [m.name for m in t.getmembers() if m.isfile()]
    except Exception as e:
        return False, f"unreadable archive: {e}"
    real = [n for n in names
            if "/share/hud/info/" not in n
            and not re.search(r"\.dist-info/", n)
            and not re.search(r"\.egg-info/", n)]
    if not real:
        return False, f"no payload: {len(names)} files, all metadata"
    size = os.path.getsize(art)
    return True, f"{len(real)} payload files, {size} bytes"


def publish(art):
    base = os.path.basename(art)
    rc, log = sh(f"scp -q -o BatchMode=yes {art} {BFREPO}:{INBOX}/{base}")
    if rc:
        return False, f"scp failed: {log.strip()[:200]}"
    rc, log = sh(f"ssh -o BatchMode=yes {BFREPO} "
                 f"'{WRAP} add --replace {INBOX}/{base} && {WRAP} update-index'")
    if rc:
        return False, f"publish failed: {log.strip()[-400:]}"
    if "Index updated" not in log:
        return False, f"index not updated: {log.strip()[-300:]}"
    return True, log.strip()[-200:]


def already_v2(pkg):
    s = open(f"{H}/{pkg}/{pkg}.huddef", errors="replace").read()
    return "Source-SHA256:" in s and re.search(r"^Build-Depends:", s, re.M)


def one(pkg):
    rec = {"pkg": pkg}
    t0 = time.time()

    if not already_v2(pkg):
        rc, log = sh(f"python3 {REPO}/scripts/convert-python.py {pkg}", timeout=300)
        if rc:
            rec.update(stage="convert", ok=False, note=log.strip()[-200:])
            return rec
        try:
            rec["convert"] = json.loads(log)
        except Exception:
            rec["convert"] = {"raw": log.strip()[-200:]}
        if rec["convert"].get("status") != "converted":
            rec.update(stage="convert", ok=False, note=str(rec["convert"]))
            return rec
    else:
        rec["convert"] = {"status": "already v2"}

    rc, log = sh(f"hud-build {H}/{pkg}/{pkg}.huddef")
    rec["build_s"] = int(time.time() - t0)
    if rc:
        m = re.findall(r"(?:error|Error|ERROR)[:\s].{0,120}", log)
        rec.update(stage="build", ok=False, note=(m[-1] if m else log.strip()[-200:]))
        return rec

    art = artifact(pkg)
    if not art:
        rec.update(stage="artifact", ok=False, note="build reported success but produced no .hud")
        return rec

    good, why = payload_ok(art)
    rec["payload"] = why
    if not good:
        # This is the defect itself surviving the fix. Never publish it.
        rec.update(stage="payload", ok=False, note=why)
        return rec

    t1 = time.time()
    predeps = declared_depends(art)
    rec["test_deps"] = predeps
    dflag = f'--deps "{" ".join(predeps)}" ' if predeps else ""
    rc, log = sh(f"hud-test {dflag}--local {art}", timeout=3600)
    rec["test_s"] = int(time.time() - t1)
    if rc:
        # the LAST failure marker, not the first bracket in the log: matching
        # r"\[.\]" caught the "[OK] install" line and reported a success string
        # as the reason python3-lxml failed.
        clean = re.sub(r"\x1b\[[0-9;]*m", "", log)
        bad = re.findall(r"^.*\[.\].*(?:fail|error|unresolved|✗).*$", clean,
                         re.M | re.I) or re.findall(r"^.*\[✗\].*$", clean, re.M)
        rec.update(stage="test", ok=False,
                   note=(bad[-1].strip()[:200] if bad else clean.strip()[-200:]))
        return rec

    ok, why = publish(art)
    if not ok:
        rec.update(stage="publish", ok=False, note=why)
        return rec

    rec.update(stage="published", ok=True, artifact=os.path.basename(art))
    return rec


def main(listfile):
    pkgs = json.load(open(listfile))
    state = load_state()
    results = []
    for pkg in pkgs:
        if pkg in state["published"]:
            print(f"  {pkg}: already published, skipping", flush=True)
            continue
        print(f"  {pkg} ...", flush=True)
        try:
            rec = one(pkg)
        except Exception as e:
            # One package must never be able to end the run for the rest.
            rec = {"pkg": pkg, "stage": "driver", "ok": False,
                   "note": f"{type(e).__name__}: {e}"[:200]}
        results.append(rec)
        if rec.get("ok"):
            state["published"].append(pkg)
            state["failed"].pop(pkg, None)
            print(f"    PUBLISHED  build={rec.get('build_s')}s "
                  f"test={rec.get('test_s')}s  {rec.get('payload')}", flush=True)
        else:
            state["failed"][pkg] = {"stage": rec.get("stage"), "note": rec.get("note")}
            print(f"    FAIL at {rec.get('stage')}: {rec.get('note')}", flush=True)
        save_state(state)
        json.dump(results, open("/var/hud-build/e5-results.json", "w"), indent=1)
    print(f"\npublished {len(state['published'])} / {len(pkgs)} requested; "
          f"{len(state['failed'])} failed", flush=True)


if __name__ == "__main__":
    main(sys.argv[1])
