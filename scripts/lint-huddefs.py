#!/usr/bin/env python3
"""
Enforce the hard rules in CLAUDE.md across every definition.

Every rule here corresponds to a defect that actually shipped:

  no-network        qemu fetched its patch with wget mid-build; wget is not
                    installed, so it never applied
  no-guarded-patch  qemu wrote `patch ... || true`, and docbook-xsl wrote
                    `if [ -f ../patch ]`, which is the same thing wearing a hat
  sha256-required   a Source without a hash is an unverified download
  patch-in-repo     a `Patches:` entry with no file in patches/ fails the build
                    late instead of failing the lint early
  no-v1-patch-url   `Patch:` as a URL means the builder never fetches it
  install-stages    an [install] that mentions no $DESTDIR and no --root ships
                    an empty package — 68 of them did
  postinst-tracks   [postinst] creating a file outside the prefix leaves it
                    untracked and un-removable

Exit code is the number of definitions with at least one error, so it works as
a gate.
"""
import os, re, sys

H = "huddefs"
SECTION = re.compile(r"^\[([a-z]+)\]\s*$", re.M)
BUILD_SECTIONS = ("configure", "build", "install", "check")


def sections(text):
    head, _, rest = text.partition("\n[")
    rest = "[" + rest if rest else ""
    out, cur, buf = {}, None, []
    for line in rest.splitlines():
        m = SECTION.match(line)
        if m:
            if cur:
                out[cur] = "\n".join(buf)
            cur, buf = m.group(1), []
        elif cur is not None:
            buf.append(line)
    if cur:
        out[cur] = "\n".join(buf)
    return head, out


def _pip_is_offline(line):
    """A pip install that cannot reach an index.

    Two forms are legitimate: --no-index, and installing from a local path or a
    local wheel directory. python3-distlib does the second — `pip3 install
    --root=$DESTDIR .` — and flagging it for lacking --no-index was wrong.
    """
    if "--no-index" in line:
        return True
    if "--find-links" in line:
        return True
    # A local target given as its own argument: ".", "$PWD", "./something".
    # Matching only at end-of-line was wrong — python3-distlib writes
    #   pip3 install --no-deps --prefix=/opt/hud --root=$DESTDIR . --break-system-packages
    # with the "." in the middle, and it was reported as a network install.
    for tok in re.split(r"\s+", line.strip()):
        if tok in (".", "$PWD", "./") or tok.startswith("./"):
            return True
    return False


def code(body):
    """Lines that actually run — comments are where the explanations live."""
    return [l for l in body.splitlines()
            if l.strip() and not l.strip().startswith("#")]


def check(pkg):
    f = os.path.join(H, pkg, f"{pkg}.huddef")
    head, secs = sections(open(f, errors="replace").read())
    v2 = "Source-SHA256:" in head and re.search(r"^Build-Depends:", head, re.M)
    errs, warns = [], []

    if re.search(r"^Patch:\s*http", head, re.M):
        errs.append("no-v1-patch-url: `Patch:` names a URL; the builder never fetches it")

    src = re.search(r"^Source:\s*(\S+)", head, re.M)
    if src and src.group(1) != "none" and v2 and "Source-SHA256:" not in head:
        errs.append("sha256-required: Source is a URL with no Source-SHA256")

    pat = re.search(r"^Patches:\s*(.*)$", head, re.M)
    if pat:
        for name in [x.strip() for x in pat.group(1).split(",") if x.strip()]:
            if not os.path.exists(os.path.join(H, pkg, "patches", name)):
                errs.append(f"patch-in-repo: Patches names {name}, not in patches/")

    for name in BUILD_SECTIONS:
        for line in code(secs.get(name, "")):
            if re.search(r"\b(wget|curl)\b", line) and "--version" not in line:
                errs.append(f"no-network: [{name}] runs a downloader: {line.strip()[:60]}")
            if re.search(r"\bpip3?\s+install\b", line) and not _pip_is_offline(line):
                errs.append(f"no-network: [{name}] pip install that can reach the network: {line.strip()[:60]}")
            if re.search(r"^\s*patch\s.*\|\|\s*true", line):
                errs.append(f"no-guarded-patch: [{name}] `patch ... || true`")
            if re.search(r"^\s*if\s+\[\s+-f\s+\.\..*patch", line):
                errs.append(f"no-guarded-patch: [{name}] apply guarded on the patch existing")

    # Staging, but only for the commands that cannot pick DESTDIR up on their own.
    #
    # hud-build exports DESTDIR=/dest, and make, ninja and meson all honour it
    # from the environment — `make install` with no DESTDIR on the line stages
    # correctly, which is why python3-py3c ships all twelve of its headers
    # despite looking wrong. Flagging those was the lint's own false positive.
    #
    # pip is the one that does not: it needs --root explicitly, and its absence
    # is exactly the defect that left 66 packages holding nothing but metadata.
    for line in code(secs.get("install", "")):
        if re.search(r"\bpip3?\s+install\b", line) and "--root" not in line:
            errs.append(f"install-stages: pip install without --root; the package will be empty: {line.strip()[:60]}")
        m = re.match(r"\s*(?:install\s+(?:-\S+\s+)*|cp\s+(?:-\S+\s+)*\S+\s+)(/\S+)", line)
        if m and "$DESTDIR" not in line and "${DESTDIR}" not in line:
            errs.append(f"install-stages: writes to {m.group(1)} outside $DESTDIR")

    for line in code(secs.get("postinst", "")):
        m = re.match(r"\s*(?:install\s+-\S*d\S*|mkdir|ln\s+-\S+|cp)\s+.*?(/(?!opt/hud)\S+)", line)
        if m and not m.group(1).startswith(("/opt/hud", "/dev", "/proc", "/sys", "/run")):
            warns.append(f"postinst-tracks: creates {m.group(1)} outside the prefix")
    return errs, warns


def main():
    only = sys.argv[1:] or sorted(p for p in os.listdir(H)
                                  if os.path.exists(f"{H}/{p}/{p}.huddef"))
    bad = warned = 0
    for p in only:
        e, w = check(p)
        if e:
            bad += 1
            print(f"\n\033[31m{p}\033[0m")
            for x in e:
                print(f"    ERROR  {x}")
            for x in w:
                print(f"    warn   {x}")
        elif w:
            warned += 1
    print(f"\n{len(only)} definitions: {bad} with errors, {warned} with warnings only")
    return bad


if __name__ == "__main__":
    sys.exit(main())
