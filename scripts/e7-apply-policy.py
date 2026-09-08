#!/usr/bin/env python3
"""
Apply docs/file-ownership-policy.md to a definition's [postinst].

Three mechanical transformations, each one the policy's answer to a category the
E7 inventory already classified:

  systemd unit    a heredoc writing /etc/systemd/system/<x>  ->  the same
                  heredoc into $DESTDIR/usr/local/lib/systemd/system/<x>, moved
                  into [install]. /etc/systemd/system is the admin's, and the
                  prefix is not on systemd's search path at all.

  admin config    a heredoc writing /etc/<x>  ->  the content ships as
                  $DESTDIR/opt/hud/share/<pkg>/defaults/<x>, and [postinst]
                  copies it only if the target is absent. Never clobber a file
                  an administrator may have edited — linux-pam overwrites five
                  files under /etc/pam.d and getting that wrong locks everyone
                  out.

  program file    a heredoc writing /usr/bin/<x> or a polkit rule  ->  shipped
                  under $DESTDIR, tracked, removable.

Reports what it changed and leaves anything it cannot place confidently alone,
so the result is reviewable rather than assumed.
"""
import os, re, sys

H = "huddefs"
SECTION = re.compile(r"^\[([a-z]+)\]\s*$", re.M)

UNIT_DIR    = "$DESTDIR/usr/local/lib/systemd/system"
DEFAULTS    = "$DESTDIR/opt/hud/share/{pkg}/defaults"


def split(text):
    head, _, rest = text.partition("\n[")
    rest = "[" + rest if rest else ""
    order, secs, cur, buf = [], {}, None, []
    for line in rest.splitlines():
        m = SECTION.match(line)
        if m:
            if cur:
                secs[cur] = "\n".join(buf)
            cur = m.group(1); order.append(cur); buf = []
        elif cur is not None:
            buf.append(line)
    if cur:
        secs[cur] = "\n".join(buf)
    return head, order, secs


def heredocs(body):
    """Yield (start, end, path, marker, block) for each `cat > /abs/path << "EOF"`."""
    lines = body.splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r'\s*cat\s*>\s*(/\S+)\s*<<\s*[\'"]?(\w+)[\'"]?\s*$', lines[i])
        if m:
            path, marker = m.group(1), m.group(2)
            j = i + 1
            while j < len(lines) and lines[j].strip() != marker:
                j += 1
            if j < len(lines):
                yield i, j, path, marker, lines[i:j + 1]
                i = j + 1
                continue
        i += 1


# Drop-in directories that hold one file per package, named for it. Nothing
# else edits them, so there is no admin file to clobber and the .default dance
# would add nothing — they simply ship.
PACKAGE_OWNED = re.compile(r"^/etc/(ld\.so\.conf\.d|profile\.d|binfmt\.d|"
                           r"sysctl\.d|modules-load\.d|tmpfiles\.d)/")


def classify(path, pkg):
    if path.startswith("/etc/systemd/system/"):
        return "unit"
    if path.startswith(("/usr/bin/", "/usr/share/polkit-1/")):
        return "program"
    if PACKAGE_OWNED.match(path):
        # ...but only if the file is named for THIS package. nftables writes
        # /etc/ld.so.conf.d/hud.conf, which several packages write with the same
        # content — shipping it from nftables would let `hud remove nftables`
        # delete the library path every other hud package depends on. A shared
        # file is infrastructure, like the ld.so cache itself, and stays in
        # [postinst].
        stem = os.path.splitext(os.path.basename(path))[0]
        if stem == pkg or stem == pkg.replace("python3-", ""):
            return "dropin"
        return None
    if path.startswith("/etc/"):
        return "config"
    return None


def main(pkgs):
    for pkg in pkgs:
        f = os.path.join(H, pkg, f"{pkg}.huddef")
        if not os.path.exists(f):
            print(f"{pkg}: no definition"); continue
        head, order, secs = split(open(f, errors="replace").read())
        post = secs.get("postinst", "")
        if not post:
            print(f"{pkg}: no [postinst]"); continue

        moved_install, keep, changes = [], [], []
        lines = post.splitlines()
        consumed = set()

        # Directories and symlinks outside the prefix. Same rule as the first
        # ten E7 packages: created in [postinst] they are untracked and survive
        # `hud remove`, so they move into [install] under $DESTDIR.
        #
        # /etc/ld.so.conf.d/hud.conf is deliberately left alone: several
        # packages write the same file with the same content, so it is shared
        # infrastructure like the ld.so cache itself, not a file any one package
        # owns.
        for i, line in enumerate(lines):
            m = re.match(r"\s*(?:install\s+-\S*d\S*|mkdir(?:\s+-\S+)*)\s+(/\S+)", line)
            if m and not m.group(1).startswith(("/opt/hud", "/run", "/proc", "/sys")):
                consumed.add(i)
                moved_install.append(f"install -v -dm755 $DESTDIR{m.group(1)}")
                changes.append(f"dir {m.group(1)} -> staged")
                continue
            m = re.match(r"\s*ln\s+(-\S+)\s+(\S+)\s+(/\S+?)(?:\s+2>|\s*\|\||\s*$)", line)
            if m and not m.group(3).startswith(("/opt/hud", "/run")):
                consumed.add(i)
                d = os.path.dirname(m.group(3))
                moved_install.append(
                    f"install -v -dm755 $DESTDIR{d}\n"
                    f"ln -sfn {m.group(2)} $DESTDIR{m.group(3)}")
                changes.append(f"symlink {m.group(3)} -> staged")
        # The redirect form: `printf '...' > /etc/systemd/system/x.service`.
        # networkmanager writes all seven of its files this way, so a
        # heredoc-only transformer left it untouched.
        for i, line in enumerate(lines):
            if i in consumed:
                continue
            m = re.match(r"\s*((?:printf|echo)\s+.*?)\s*>\s*(/\S+)\s*$", line)
            if not m:
                continue
            content, path = m.group(1), m.group(2)
            kind = classify(path, pkg)
            if kind is None:
                continue
            consumed.add(i)
            name = os.path.basename(path)
            if kind == "unit":
                moved_install.append(f"install -v -dm755 {UNIT_DIR}\n"
                                     f"{content} > {UNIT_DIR}/{name}")
                changes.append(f"unit {name} -> /usr/local/lib/systemd/system")
            elif kind in ("program", "dropin"):
                d = os.path.dirname(path)
                moved_install.append(f"install -v -dm755 $DESTDIR{d}\n"
                                     f"{content} > $DESTDIR{path}")
                changes.append(f"{kind} {path} -> shipped and tracked")
            else:
                dd = DEFAULTS.format(pkg=pkg)
                moved_install.append(f"install -v -dm755 {dd}\n"
                                     f"{content} > {dd}/{name}")
                keep.append(
                    f"# {path}: ship a default, never clobber an edited file.\n"
                    f"if [ ! -e {path} ]; then\n"
                    f"    install -v -Dm644 /opt/hud/share/{pkg}/defaults/{name} {path}\n"
                    f"fi")
                changes.append(f"config {path} -> .default + copy-if-absent")

        for start, end, path, marker, block in heredocs(post):
            kind = classify(path, pkg)
            if kind is None:
                continue
            consumed.update(range(start, end + 1))
            name = os.path.basename(path)
            body = "\n".join(block[1:-1])
            if kind == "unit":
                moved_install.append(
                    f'install -v -dm755 {UNIT_DIR}\n'
                    f'cat > {UNIT_DIR}/{name} << "{marker}"\n{body}\n{marker}')
                changes.append(f"unit {name} -> /usr/local/lib/systemd/system")
            elif kind in ("program", "dropin"):
                d = os.path.dirname(path)
                mode = "755" if path.startswith("/usr/bin/") else "644"
                moved_install.append(
                    f'install -v -dm755 $DESTDIR{d}\n'
                    f'cat > $DESTDIR{path} << "{marker}"\n{body}\n{marker}\n'
                    f'chmod {mode} $DESTDIR{path}')
                changes.append(f"{kind} {path} -> shipped and tracked")
            else:
                dd = DEFAULTS.format(pkg=pkg)
                moved_install.append(
                    f'install -v -dm755 {dd}\n'
                    f'cat > {dd}/{name} << "{marker}"\n{body}\n{marker}')
                keep.append(
                    f'# {path}: ship a default, never clobber an edited file.\n'
                    f'if [ ! -e {path} ]; then\n'
                    f'    install -v -Dm644 /opt/hud/share/{pkg}/defaults/{name} {path}\n'
                    f'fi')
                changes.append(f"config {path} -> .default + copy-if-absent")

        if not changes:
            print(f"{pkg}: nothing to move"); continue

        newpost = "\n".join(l for i, l in enumerate(lines) if i not in consumed)
        newpost = re.sub(r"\n{3,}", "\n\n", newpost).rstrip() + "\n\n" + "\n\n".join(keep)
        secs["postinst"] = newpost.rstrip() + "\n"
        secs["install"] = (secs.get("install", "").rstrip() + "\n\n"
                           + "# Moved out of [postinst] by docs/file-ownership-policy.md:\n"
                           + "# anything created there is untracked and survives `hud remove`.\n"
                           + "\n\n".join(moved_install) + "\n")
        body = "\n".join(f"[{s}]\n{secs[s].rstrip()}\n" for s in order if s in secs)
        open(f, "w").write(head.rstrip("\n") + "\n\n" + body)
        print(f"{pkg}: {len(changes)} change(s)")
        for c in changes:
            print(f"    {c}")


if __name__ == "__main__":
    main(sys.argv[1:])
