#!/usr/bin/env python3
"""
convert-python.py — E5/E6: fix the python3-* packages.

One defect explains all 66 SUSPECT-EMPTY packages. Their [install] runs pip
without --root=$DESTDIR, so pip installed into the build container's own Python
and $DESTDIR stayed empty. The resulting .hud contained metadata and no payload:
~750 bytes each. python3-distlib is the one that got it right:

    pip3 install --no-deps --prefix=/opt/hud --root=$DESTDIR . --break-system-packages

E5 and E6 are the same pass because they are the same packages. Two distinct
changes:

  E5  add --prefix=/opt/hud --root=$DESTDIR so the payload is staged
  E6  a pip invocation that can reach the network becomes a Build-Depends on the
      already-packaged module. `--no-index --find-links dist` is offline and is
      kept: it installs a wheel built from the source tree in [build].

Also removed, because v2 does not support them and they were silently ignored:
  [prerm] pip3 uninstall   — files are tracked in FILES; hud remove handles them
  [postrm]                 — hud-build emits postinst and prerm only
"""
import hashlib, json, os, re, sys

REPO  = "/root/github-repo/huddefs"
H     = f"{REPO}/huddefs"
CACHE = "/var/hud-build/cache"

SECTION_RE = re.compile(r'^\[([a-z]+)\]\s*$', re.M)


def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for c in iter(lambda: fh.read(65536), b""):
            h.update(c)
    return h.hexdigest()


def split_sections(text):
    head, _, rest = text.partition("\n[")
    rest = "[" + rest if rest else ""
    secs, order, cur, buf = {}, [], None, []
    for line in rest.splitlines():
        m = SECTION_RE.match(line)
        if m:
            if cur:
                secs[cur] = "\n".join(buf)
            cur = m.group(1)
            order.append(cur)
            buf = []
        elif cur is not None:
            buf.append(line)
    if cur:
        secs[cur] = "\n".join(buf)
    return head, order, secs


def fix_install(body, pkg):
    """Add --prefix/--root to the pip install so the payload lands in $DESTDIR."""
    out, changed = [], False
    for line in body.splitlines():
        if re.search(r'\bpip3?\s+install\b', line) and "$DESTDIR" not in line:
            # keep the existing flags, add the ones that make it stage properly
            new = line.rstrip()
            if "--prefix" not in new:
                new = re.sub(r'(\bpip3?\s+install\b)', r'\1 --prefix=/opt/hud', new, count=1)
            if "--root" not in new:
                new = re.sub(r'(--prefix=\S+)', r'\1 --root=$DESTDIR', new, count=1)
            if "--no-deps" not in new:
                new = re.sub(r'(\bpip3?\s+install\b)', r'\1 --no-deps', new, count=1)
            if "--break-system-packages" not in new:
                new += " --break-system-packages"
            # drop flags that conflict with a staged install
            new = new.replace(" --no-user", "")
            out.append(new)
            changed = True
        else:
            out.append(line)
    return "\n".join(out), changed


def network_pip(body):
    """A pip install that could reach the network: no --no-index and no local dir."""
    for line in body.splitlines():
        if re.search(r'\bpip3?\s+install\b', line) and "--no-index" not in line \
           and "--find-links" not in line and not re.search(r'\s\.\s|\s\$PWD|\sdist\b', line):
            return line.strip()
    return None


def convert(pkg):
    f = os.path.join(H, pkg, f"{pkg}.huddef")
    text = open(f, errors="replace").read()
    head, order, secs = split_sections(text)

    m = re.search(r"^Source:\s*(\S+)", head, re.M)
    if not m:
        return "no-source", None
    tarball = os.path.join(CACHE, os.path.basename(m.group(1)))
    if not os.path.exists(tarball):
        return f"tarball-missing:{os.path.basename(tarball)}", None

    notes = []

    # E5: stage the install
    if "install" in secs:
        secs["install"], changed = fix_install(secs["install"], pkg)
        if changed:
            notes.append("added --prefix=/opt/hud --root=$DESTDIR")

    # E6: a pip that can reach the network is not allowed during a build
    netline = None
    for s in ("configure", "build", "install", "check"):
        if s in secs:
            nl = network_pip(secs[s])
            if nl:
                netline = (s, nl)
                break

    # drop sections v2 does not support / that fight the package manager
    for dead, why in (("prerm", "pip3 uninstall — files are tracked in FILES"),
                      ("postrm", "not supported by hud-build")):
        if dead in secs and (dead != "prerm" or "pip" in secs[dead]):
            del secs[dead]
            order = [o for o in order if o != dead]
            notes.append(f"removed [{dead}] ({why})")

    # header: Source-SHA256, Build-Depends preserved, Depends/Provides auto
    bd_m = re.search(r"^Build-Depends:[ \t]*(.*)$", head, re.M)
    dep_m = re.search(r"^Depends:[ \t]*(.*)$", head, re.M)
    base = (bd_m.group(1) if bd_m is not None else (dep_m.group(1) if dep_m else ""))
    bd = [d.strip() for d in base.split(",") if d.strip() and d.strip().lower() != "auto"]

    lines, seen = [], set()
    for line in head.rstrip("\n").splitlines():
        fm = re.match(r"^([A-Za-z0-9-]+):[ \t]*(.*)$", line)
        if not fm:
            lines.append(line)
            continue
        key = fm.group(1).lower()
        if key in ("depends", "source-sha256", "build-depends", "provides"):
            continue
        lines.append(line)
        seen.add(key)
        if key == "source":
            lines.append(f"Source-SHA256:    {sha256(tarball)}")
    if "source" not in seen:
        return "no-source-field", None
    lines += ["", f"Build-Depends:    {', '.join(bd)}",
              "Depends:          auto", "Provides:         auto"]

    body = "\n".join(f"[{s}]\n{secs[s].rstrip()}\n" for s in order if s in secs)
    open(f, "w").write("\n".join(lines) + "\n\n" + body)
    return "converted", {"build_depends": bd, "notes": notes, "network_pip": netline}


if __name__ == "__main__":
    st, info = convert(sys.argv[1])
    print(json.dumps({"status": st, **(info or {})}, indent=1))
