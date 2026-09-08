#!/usr/bin/env python3
"""
E7 inventory — every action in the 24 ABSOLUTE-PATH packages that touches a path
the package will not track.

CLAUDE.md rule 5 says what the answer is, so this classifies rather than judges:

  ship        a directory or symlink created outside $DESTDIR. Belongs in
              [install] under $DESTDIR, where it lands in FILES and `hud remove`
              cleans it up.
  config      a file written to a location an admin may already have edited.
              Ships as <name>.default; [postinst] copies it only if the target
              is absent.
  runtime     legitimately not a file: ldconfig, systemctl, useradd. Stays.
  unit-in-prefix  a systemd unit written under /opt/hud but still by postinst,
              so still untracked. Same fix as `ship`.
  review      anything this cannot place confidently.
"""
import json, os, re, sys

H = "/root/github-repo/huddefs/huddefs"
PREFIX = "/opt/hud"

SECTION = re.compile(r"^\[([a-z]+)\]\s*$", re.M)

RUNTIME = re.compile(r"^\s*(ldconfig|systemctl|udevadm|update-desktop-database|"
                     r"gtk-update-icon-cache|glib-compile-schemas|useradd|groupadd|"
                     r"echo|:|#|fi|else|then|done|esac)\b")

# a write to somewhere the package does not own
WRITES = [
    ("mkdir",   re.compile(r"^\s*mkdir\s+(?:-\S+\s+)*(/\S+)")),
    ("install", re.compile(r"^\s*install\s+(?:-\S+\s+)*(/\S+)\s*(?:&&)?\s*$")),
    ("install", re.compile(r"^\s*install\s+.*?\s(/\S+)\s*(?:&&)?\s*$")),
    ("ln",      re.compile(r"^\s*ln\s+-\S+\s+\S+\s+(/\S+)")),
    ("cp",      re.compile(r"^\s*cp\s+(?:-\S+\s+)*\S+\s+(/\S+)")),
    ("heredoc", re.compile(r"^\s*cat\s*>\s*(/\S+)\s*<<")),
    ("redirect",re.compile(r"^\s*\S.*?>\s*(/\S+)\s*$")),
    ("chmod",   re.compile(r"^\s*chmod\s+(?:-\S+\s+)*\S+\s+(/\S+)")),
]

CONFIGISH = re.compile(r"^/etc/|\.conf$|\.cfg$|\.ini$")

# Drop-in directories whose contents belong to a package rather than to the
# admin: one file per package, named after it, and nothing else edits it. These
# are `ship`, not `config` — there is no existing file to avoid clobbering, so
# the .default dance would add nothing.
PACKAGE_OWNED = re.compile(r"^/etc/(ld\.so\.conf\.d|profile\.d|binfmt\.d|"
                           r"sysctl\.d|modules-load\.d|tmpfiles\.d)/")


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
    return out


def classify(sec, path, verb):
    if sec == "install" and "$DESTDIR" in path:
        return None
    if PACKAGE_OWNED.match(path):
        return "ship" if sec != "install" else None
    if path.startswith(PREFIX):
        # correct destination, wrong section: postinst still leaves it untracked
        return "unit-in-prefix" if sec != "install" else None
    if verb in ("mkdir",) or (verb == "install" and re.search(r"-\S*d", verb)):
        return "ship"
    if verb == "ln":
        return "ship"
    if verb in ("heredoc", "redirect", "cp") and CONFIGISH.search(path):
        return "config"
    if verb == "install" and CONFIGISH.search(path):
        return "config"
    return "review"


def scan(pkg):
    f = f"{H}/{pkg}/{pkg}.huddef"
    if not os.path.exists(f):
        return {"error": "no definition"}
    secs = sections(open(f, errors="replace").read())
    found = []

    # The compliant pattern from docs/file-ownership-policy.md: the file ships
    # as a tracked default inside the prefix and [postinst] copies it into place
    # only when the target is absent. That is a write to /etc and it is the
    # intended one, so reporting it would make the scanner flag its own answer.
    compliant = set()
    for m in re.finditer(r"if\s+\[\s+!\s+-e\s+(\S+)\s*\]", secs.get("postinst", "")):
        compliant.add(m.group(1))
    for sec in ("configure", "build", "install", "check", "postinst", "prerm", "postrm"):
        body = secs.get(sec)
        if not body:
            continue
        for line in body.splitlines():
            # Check for a redirection BEFORE the runtime skip. `echo "/opt/hud/lib64"
            # > /etc/ld.so.conf.d/gperftools.conf` starts with echo, and skipping it
            # as a runtime command hid a real untracked write in six packages.
            redirected = re.match(r"^\s*\S.*?>\s*(/\S+)\s*$", line) is not None
            if RUNTIME.match(line) and not redirected:
                continue
            for verb, rx in WRITES:
                m = rx.match(line)
                if not m:
                    continue
                path = m.group(1)
                if "$DESTDIR" in path or path.startswith("$"):
                    break
                # `install -dm755 /x` — directory creation
                v = verb
                if verb == "install" and re.search(r"-\S*d\S*\s", line):
                    v = "mkdir"
                if sec == "postinst" and path in compliant:
                    break
                kind = classify(sec, path, v)
                if kind:
                    found.append({"section": sec, "verb": v, "path": path,
                                  "kind": kind, "line": line.strip()[:120]})
                break
    return {"actions": found}


if __name__ == "__main__":
    pkgs = json.load(open(sys.argv[1]))
    out = {p: scan(p) for p in pkgs}
    json.dump(out, open(sys.argv[2], "w"), indent=1)
    tot = {}
    for p, d in out.items():
        for a in d.get("actions", []):
            tot[a["kind"]] = tot.get(a["kind"], 0) + 1
    print("packages scanned:", len(out))
    for k, v in sorted(tot.items()):
        print(f"  {k:<16} {v}")
