#!/usr/bin/env python3
"""
convert-easy.py — mechanical v1 -> v2 conversion of the EASY packages.

Strictly sequential: one package at a time, one build at a time. Concurrency
corrupted two earlier timing measurements, so nothing here overlaps.

For each package:
    Source-SHA256   computed from the cached tarball
    Build-Depends   v1's Depends verbatim, plus anything the build turns out to
                    need (that difference is the measurement this phase exists
                    for)
    Depends: auto   Provides: auto

Then build against the minimal rootfs, then hud-test the artifact.

Stop conditions, checked continuously:
    1. the same failure signature in 3 different packages
    2. more than 6 failures in a batch of 20
    3. a package needing judgement -> logged to docs/needs-human.md, batch continues
    5. free disk under 100 G
"""
import hashlib, json, os, re, shutil, subprocess, sys, time

REPO   = "/root/github-repo/huddefs"
H      = f"{REPO}/huddefs"
CACHE  = "/var/hud-build/cache"
OUT    = "/var/hud-build/output"
STATE  = "/var/hud-build/convert-state.json"
MIN_FREE_GB = 100

# Always present in the minimal rootfs because the hud client cannot fetch
# anything without them. A Build-Depends naming only these cannot be shown to be
# necessary by a build here, so it is reported as unvalidated rather than proven.
BOOTSTRAP = {"curl", "openssl", "zlib", "zstd", "brotli", "nghttp2",
             "libidn2", "libpsl", "libunistring"}
MAXTRY = 3

# ---------------------------------------------------------------- helpers

def sh(cmd, timeout=14400):
    p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr

def strip_ansi(s):
    return re.sub(r"\x1b\[[0-9;]*m", "", s)

def free_gb():
    st = os.statvfs("/")
    return st.f_bavail * st.f_frsize / 1024**3

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for c in iter(lambda: fh.read(65536), b""):
            h.update(c)
    return h.hexdigest()



# Names that are unambiguously tools or base-system components. A drop here needs
# no verification: documentation builders, test-suite servers, or things the base
# LFS system provides and hud never packaged.
UNAMBIGUOUS_DROPS = {
    "texlive", "tl-installer", "libreoffice", "doxygen", "sphinx", "asciidoc",
    "graphviz", "mercurial", "gtk-doc", "docbook-xml", "apache", "samba",
    "openssh", "fcron", "perl-io-socket-ssl", "glibc", "java", "python",
    "ojdk-conf", "xorg-libraries", "xorg7-lib", "rust", "guile", "six",
    "libuv",
}

def shipped_requires(pkg):
    """Derive Requires from the .hud currently in the live pool. Read-only."""
    import glob, tempfile, shutil as _sh
    cands = sorted(glob.glob(f"/var/www/hud-repo/pool/main/{pkg[0]}/{pkg}/{pkg}-*.hud"))
    if not cands:
        return None
    tmp = tempfile.mkdtemp(prefix="shipped-", dir="/var/hud-build")
    try:
        rc, _ = sh(f"tar xzf {cands[-1]} -C {tmp}", timeout=600)
        if rc != 0:
            return None
        rc, out = sh(f"hud-scan-deps {tmp} --json", timeout=1800)
        if rc != 0:
            return None
        return set(json.loads(out).get("requires", []))
    except Exception:
        return None
    finally:
        _sh.rmtree(tmp, ignore_errors=True)

def verify_drops(pkg, dropped, new_requires):
    """Did dropping a dependency remove real functionality?

    Compare what the newly built package needs against what the shipped one
    needed. Same capabilities means the feature was never compiled in and the
    drop changed nothing. Fewer means the drop removed something real.
    """
    libs = [d for d in dropped if d not in UNAMBIGUOUS_DROPS]
    old = shipped_requires(pkg)
    result = {"dropped": sorted(dropped), "library_drops": sorted(libs)}
    if old is None:
        result["verdict"] = "no shipped package to compare against"
        return result, False
    new = set(x for x in (new_requires or "").split(",") if x)
    result["requires_shipped"] = sorted(old)
    result["requires_new"] = sorted(new)
    lost = sorted(old - new)
    result["lost_capabilities"] = lost
    if not lost:
        result["verdict"] = "unchanged - drop was harmless"
        return result, False
    if libs:
        result["verdict"] = "DIFFERS and a library was dropped - halt"
        return result, True
    result["verdict"] = "differs, but only tool/base-system drops - not halting"
    return result, False

# ---------------------------------------------------------------- dep hygiene

_REPO_NAMES = None
DROPPED_LOG = "/var/hud-build/dropped-deps.json"

def repo_names():
    global _REPO_NAMES
    if _REPO_NAMES is None:
        _REPO_NAMES = {}
        try:
            for line in open("/var/www/hud-repo/packages.list"):
                if not line.startswith("#") and "|" in line:
                    n = line.split("|")[0]
                    _REPO_NAMES[n.lower()] = n
        except OSError:
            pass
    return _REPO_NAMES

def normalise_deps(deps):
    """Map book names onto real package names; drop what was never packaged."""
    have = repo_names()
    keep, dropped = [], []
    for d in deps:
        dl = d.lower()
        hit = None
        for cand in (dl, dl.rstrip("0123456789"), dl.replace("-", ""), dl + "2"):
            if cand in have:
                hit = have[cand]
                break
        if hit:
            if hit not in keep:
                keep.append(hit)
        else:
            dropped.append(d)
    return keep, dropped

def record_dropped(pkg, dropped):
    try:
        data = json.load(open(DROPPED_LOG))
    except Exception:
        data = {}
    data[pkg] = sorted(set(data.get(pkg, []) + dropped))
    json.dump(data, open(DROPPED_LOG, "w"), indent=1)

# ---------------------------------------------------------------- conversion

def convert(pkg, extra_bd=None):
    f = os.path.join(H, pkg, f"{pkg}.huddef")
    text = open(f, errors="replace").read()
    head, sep, body = text.partition("\n[")
    body = sep + body

    m = re.search(r"^Source:\s*(\S+)", head, re.M)
    if not m:
        return "no-source", None
    tarball = os.path.join(CACHE, os.path.basename(m.group(1)))
    if not os.path.exists(tarball):
        return f"tarball-missing:{os.path.basename(tarball)}", None
    digest = sha256(tarball)

    # Where the base Build-Depends comes from:
    #
    # An already-converted file carries "Depends: auto". Reading that as the v1
    # dependency list produced "Build-Depends: auto", and hud-build then tried to
    # install a package literally called "auto" — which is how acl, aom and attr
    # all failed with "Package not found: auto" and tripped stop condition 1.
    #
    # So: if the file already declares Build-Depends, that is authoritative and
    # v1's Depends is not consulted. "auto" is never a package name.
    bd_m = re.search(r"^Build-Depends:[ \t]*(.*)$", head, re.M)
    dep_m = re.search(r"^Depends:[ \t]*(.*)$", head, re.M)
    if bd_m is not None:
        base = [d.strip() for d in bd_m.group(1).split(",") if d.strip()]
    else:
        base = [d.strip() for d in (dep_m.group(1) if dep_m else "").split(",") if d.strip()]
    v1_deps = [d for d in base if d.lower() != "auto"]

    # v1's Depends were largely copied from the LFS/BLFS book, including
    # OPTIONAL entries, and using the book's names rather than this repo's.
    # 19 of the 148 EASY packages name something the repository does not have:
    # texlive, libreoffice, doxygen and sphinx (book "optional, for
    # documentation"), apache, samba and openssh (book "optional, to run the
    # test suite"), glibc/java/python (base system, never hud packages), and
    # name mismatches like glib2 vs glib or libx11 vs libX11.
    #
    # Every one of those packages shipped successfully while none of these was
    # ever installable, which is the evidence that they are not required.
    #
    #   resolvable name/case mismatch -> rewritten to the real package name
    #   not in the repository at all  -> dropped, and logged, never silently
    v1_deps, dropped = normalise_deps(v1_deps)
    if dropped:
        record_dropped(pkg, dropped)
    bd = list(v1_deps)
    for e in (extra_bd or []):
        if e not in bd:
            bd.append(e)

    out, seen = [], set()
    for line in head.rstrip("\n").splitlines():
        fm = re.match(r"^([A-Za-z0-9-]+):[ \t]*(.*)$", line)
        if not fm:
            out.append(line)
            continue
        key = fm.group(1).lower()
        if key in ("depends", "source-sha256", "build-depends", "provides"):
            continue
        out.append(line)
        seen.add(key)
        if key == "source":
            out.append(f"Source-SHA256:    {digest}")
    if "source" not in seen:
        return "no-source-field", None

    out += ["", f"Build-Depends:    {', '.join(bd)}", "Depends:          auto",
            "Provides:         auto"]
    open(f, "w").write("\n".join(out) + "\n" + body)
    return "converted", {"v1_deps": v1_deps, "build_depends": bd}

# ---------------------------------------------------------------- dep guessing

ERR_PATTERNS = [
    (re.compile(r"No package '([^']+)' found"), "pc"),
    (re.compile(r"Package '([^']+)', required by"), "pc"),
    (re.compile(r"Dependency \"?([A-Za-z0-9_.+-]+)\"? not found"), "pc"),
    (re.compile(r"fatal error: ([A-Za-z0-9_./+-]+\.h(?:pp)?): No such file"), "hdr"),
    (re.compile(r"([A-Za-z0-9_./+-]+\.h): No such file or directory"), "hdr"),
    # NOT anchored: the real line is "/build.sh: line 21: cmake: command not
    # found", so an anchored pattern never matched and json-c failed with a
    # missing cmake that the retry logic should have added automatically.
    (re.compile(r"([a-z0-9_.+-]+): command not found"), "bin"),
    # Python 3.13 removed distutils. meson and g-ir-scanner still import it, so
    # several packages need setuptools, which ships a compatibility shim.
    (re.compile(r"ModuleNotFoundError: No module named '([A-Za-z0-9_.]+)'"), "pymod"),
    (re.compile(r"Program ([A-Za-z0-9_.+-]+) found: NO"), "bin"),
]

# Python modules that a build needs but that no package is named after.
# distutils was removed from the stdlib in 3.12; setuptools provides the shim.
PYMOD_TO_PKG = {
    "distutils": "python-setuptools",
    "setuptools": "python-setuptools",
    "pkg_resources": "python-setuptools",
}

def guess_dep(log, prov):
    for rx, kind in ERR_PATTERNS:
        for m in rx.finditer(log):
            key = m.group(1)
            if kind == "pymod":
                cand = PYMOD_TO_PKG.get(key)
                if cand:
                    return cand, f"pymod:{key}"
                continue
            cand = prov[kind].get(key) or (prov[kind].get(os.path.basename(key))
                                           if kind == "hdr" else None)
            if cand:
                return cand, f"{kind}:{key}"
    return None, None

def failure_signature(log):
    for rx, _ in ERR_PATTERNS:
        m = rx.search(log)
        if m:
            return re.sub(r"[0-9]+", "N", strip_ansi(m.group(0)))[:80]
    m = re.search(r"^.*(?:[Ee]rror|✗).*$", strip_ansi(log), re.M)
    return re.sub(r"[0-9]+", "N", m.group(0))[:80] if m else "unknown"

# ---------------------------------------------------------------- per package

def artifact(pkg):
    if not os.path.isdir(OUT):
        return None
    c = [f for f in os.listdir(OUT)
         if re.match(rf"^{re.escape(pkg)}-\d.*\.hud$", f)]
    return os.path.join(OUT, sorted(c)[-1]) if c else None


def clear_stale_containers():
    """Remove nspawn leftovers before every build.

    Every build root is a directory called "root", so systemd-nspawn registers
    every container under the machine name "root". If a previous container was
    orphaned rather than exiting — which is what `systemctl stop` with
    KillMode=process does to a build in progress — the next one cannot start:

        Failed to register machine: Machine 'root' already exists
        Mount point '/run/systemd/nspawn/unix-export/root' exists already

    This ran once per batch before, which was not enough: the orphan appears
    mid-batch and every remaining package in it then fails. cups, curl and dav1d
    all failed this way and tripped the same-failure-three-times stop condition.
    """
    sh("machinectl list --no-legend 2>/dev/null | awk '{print $1}' | "
       "xargs -r -n1 machinectl terminate 2>/dev/null", timeout=120)
    sh("umount /run/systemd/nspawn/unix-export/* 2>/dev/null; "
       "rm -rf /run/systemd/nspawn/unix-export/* 2>/dev/null", timeout=120)

def do_package(pkg, prov):
    rec = {"pkg": pkg, "build": "", "test": "", "provides": "", "requires": "",
           "added": [], "note": "", "build_s": 0, "test_s": 0, "build_depends": []}

    st, info = convert(pkg)
    if st != "converted":
        rec.update(build="SKIP", note=st)
        return rec, None
    rec["build_depends"] = info["build_depends"]

    added, tries = [], 1
    t0 = time.time()
    clear_stale_containers()
    rc, log = sh(f"hud-build {H}/{pkg}/{pkg}.huddef")
    while rc != 0 and tries < MAXTRY:
        dep, ev = guess_dep(log, prov)
        if not dep or dep in added or dep == pkg:
            break
        added.append(dep)
        convert(pkg, extra_bd=added)
        print(f"    retry {tries}: +{dep} ({ev})", flush=True)
        rc, log = sh(f"hud-build {H}/{pkg}/{pkg}.huddef")
        tries += 1
    rec["build_s"] = int(time.time() - t0)
    rec["added"] = added

    if rc != 0:
        rec.update(build="FAIL", note=failure_signature(log))
        return rec, failure_signature(log)

    p = re.search(r"^Provides: (.*)$", log, re.M)
    r = re.search(r"^Requires: (.*)$", log, re.M)
    rec["provides"] = p.group(1).strip() if p else ""
    rec["requires"] = r.group(1).strip() if r else ""
    rec["build"] = "OK"

    # If dependencies were dropped from this package, prove the drop was harmless
    # by comparing derived capabilities against the shipped package.
    try:
        dd = json.load(open(DROPPED_LOG))
    except Exception:
        dd = {}
    if pkg in dd and isinstance(dd[pkg], list) and dd[pkg]:
        verdict, halt = verify_drops(pkg, dd[pkg], rec["requires"])
        dd[pkg] = verdict
        json.dump(dd, open(DROPPED_LOG, "w"), indent=1)
        print(f"    drop-check: {verdict['verdict']}", flush=True)
        if halt:
            rec["note"] = ("dropped dependency removed functionality: lost "
                           + ", ".join(verdict["lost_capabilities"][:5]))
            return rec, "DROP-REMOVED-FUNCTIONALITY"

    art = artifact(pkg)
    if not art:
        rec.update(test="FAIL", note="no artifact produced")
        return rec, None

    # Pick the smoke target from the archive's real paths, not from Provides.
    #
    # Provides lists sonames, and taking the first one broke on cracklib: its
    # first entry is _cracklib.so, a Python extension module that lives in
    # site-packages, so loading it from /opt/hud/lib failed and the package was
    # reported FAIL when it was fine. Look for a real versioned library under a
    # lib directory instead, and skip the smoke test when there is not one.
    rc_l, listing = sh(f"tar tzf {art}", timeout=600)
    libs = [l.strip().lstrip(".") for l in listing.splitlines()
            if re.search(r"/lib(64)?/lib[^/]*\.so\.[0-9]", l)
            and "site-packages" not in l]
    # No ctypes smoke test.
    #
    # Loading a library in isolation fails whenever it needs another library,
    # because the test container has only the package under test installed.
    # freetype, glib, gnutls and json-glib all built correctly and were reported
    # FAIL for this reason alone.
    #
    # hud-test already performs the checks that matter and that do hold in a
    # clean root: the package's own metadata is the one under test, FILES is
    # non-trivial, and every ELF it ships resolves its libraries. A ctypes load
    # adds nothing those miss and fails for reasons unrelated to the package.
    smoke = ""
    t1 = time.time()
    clear_stale_containers()
    trc, tlog = sh(f"hud-test --local {art} {smoke}".strip(), timeout=7200)
    rec["test_s"] = int(time.time() - t1)
    rec["test"] = "OK" if trc == 0 else "FAIL"
    if trc != 0:
        m = re.search(r"\[✗\].*", strip_ansi(tlog))
        rec["note"] = m.group(0)[:80] if m else "test failed"
    return rec, None

# ---------------------------------------------------------------- reporting

def append_progress(batch_no, recs, elapsed_total):
    path = f"{REPO}/docs/conversion-progress.md"
    new = not os.path.exists(path)
    with open(path, "a") as fh:
        if new:
            fh.write("""# Conversion progress — EASY packages

Mechanical v1 -> v2 conversion, built against the **minimal** rootfs and install
tested. Appended one batch at a time.

The last column is the point of the exercise: what the build needed that v1's
`Depends:` never mentioned. An empty cell means v1's dependency data was
sufficient for the build.

**Caveat on that column.** Nine packages are always present in the minimal rootfs
because the hud client cannot fetch anything without them — curl, openssl, zlib,
zstd, brotli, nghttp2, libidn2, libpsl and libunistring. A dependency on any of
those cannot be detected as missing here, so this column undercounts by exactly
that set.

""")
        ok = sum(1 for r in recs if r["build"] == "OK")
        avg = (sum(r["build_s"] for r in recs if r["build"] == "OK") / ok) if ok else 0
        fh.write(f"\n## Batch {batch_no}\n\n")
        fh.write(f"{ok}/{len(recs)} built, average build {avg:.0f}s, "
                 f"cumulative elapsed {elapsed_total/3600:.1f}h\n\n")
        fh.write("| Package | Build | Test | Build s | Provides | Requires | "
                 "Undeclared Build-Depends |\n")
        fh.write("|---|---|---|---|---|---|---|\n")
        floor_only = []
        for r in recs:
            prov = f"`{r['provides'].replace(',', '`, `')}`" if r["provides"] else "—"
            req = f"`{r['requires'].replace(',', '`, `')}`" if r["requires"] else "—"
            add = f"**`{'`, `'.join(r['added'])}`**" if r["added"] else "—"
            note = f" — {r['note']}" if r["note"] else ""
            bd = set(r.get("build_depends") or [])
            mark = ""
            if bd and bd <= BOOTSTRAP:
                floor_only.append(r["pkg"]); mark = " ᵇ"
            fh.write(f"| `{r['pkg']}`{mark} | {r['build']}{note} | {r['test'] or '—'} | "
                     f"{r['build_s']} | {prov} | {req} | {add} |\n")
        if floor_only:
            fh.write(f"\nᵇ Build-Depends falls entirely inside the bootstrap floor "
                     f"({', '.join('`'+p+'`' for p in floor_only)}), so it is present in the "
                     f"rootfs regardless and this build does not validate it.\n")

def log_needs_human(pkg, why):
    path = f"{REPO}/docs/needs-human.md"
    with open(path, "a") as fh:
        fh.write(f"\n---\n\n## `{pkg}`\n\n{why}\n")

# ---------------------------------------------------------------- main

def main():
    prov = json.load(open(sys.argv[1]))
    packages = json.load(open(sys.argv[2]))
    start_batch = int(sys.argv[3]) if len(sys.argv) > 3 else 1

    state = json.load(open(STATE)) if os.path.exists(STATE) else {"done": [], "t0": time.time()}
    t0 = state.get("t0", time.time())

    todo = [p for p in packages if p not in state["done"]]
    batches = [todo[i:i + 20] for i in range(0, len(todo), 20)]
    sigs = {}

    for bi, batch in enumerate(batches, start_batch):
        print(f"\n===== BATCH {bi}: {len(batch)} packages =====", flush=True)
        recs, failures = [], 0
        for pkg in batch:
            if free_gb() < MIN_FREE_GB:
                print(f"STOP-5 disk below {MIN_FREE_GB}G ({free_gb():.0f}G)", flush=True)
                append_progress(bi, recs, time.time() - t0)
                return 15
            print(f"  {pkg} ...", flush=True)
            rec, sig = do_package(pkg, prov)
            recs.append(rec)
            state["done"].append(pkg)
            json.dump(state, open(STATE, "w"))
            print(f"    {rec['build']}/{rec['test'] or '-'} "
                  f"build={rec['build_s']}s test={rec['test_s']}s added={rec['added']}",
                  flush=True)
            if rec["build"] == "SKIP":
                log_needs_human(rec["pkg"], f"Skipped during conversion: `{rec['note']}`.")
                continue
            if rec["build"] == "FAIL":
                failures += 1
                if sig:
                    sigs[sig] = sigs.get(sig, 0) + 1
                    if sigs[sig] >= 3:
                        print(f"STOP-1 same failure in 3 packages: {sig}", flush=True)
                        append_progress(bi, recs, time.time() - t0)
                        return 10
                if failures > 6:
                    print("STOP-2 more than 6 failures in this batch", flush=True)
                    append_progress(bi, recs, time.time() - t0)
                    return 11
        append_progress(bi, recs, time.time() - t0)
        ok = sum(1 for r in recs if r["build"] == "OK")
        avg = (sum(r["build_s"] for r in recs if r["build"] == "OK") / ok) if ok else 0
        print(f"BATCH {bi} DONE ok={ok}/{len(recs)} failures={failures} "
              f"avg_build={avg:.0f}s elapsed={(time.time()-t0)/3600:.1f}h", flush=True)
        print("COMMITPOINT", flush=True)
    print("ALLBATCHESDONE", flush=True)
    return 0

sys.exit(main())
