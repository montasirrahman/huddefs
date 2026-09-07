# Emptiness sweep — every published package, not only `python3-*`

Run 2026-09-07 against all 251 archives in `/var/www/hud-repo/pool/`. Counts
files in each `.hud` excluding `share/hud/info/` and `.owner`, which every
package has whether or not it contains anything.

Reproduce with the loop in this file's history, or against the staging pool:

```bash
python3 - <<'PY'
import os, tarfile
for root, _, files in os.walk("/var/www/hud-unstable/pool/main"):
    for f in files:
        if not f.endswith(".hud"):
            continue
        p = os.path.join(root, f)
        with tarfile.open(p) as t:
            names = [m.name for m in t.getmembers() if m.isfile()]
        payload = [n for n in names
                   if "/share/hud/info/" not in n and not n.endswith("/.owner")]
        if len(payload) <= 3:
            print(f"{f.rsplit('-', 2)[0]:<28}{len(payload)}  {payload[:4]}")
PY
```

## Result

**67 packages ship zero payload files.** 66 are the known SUSPECT-EMPTY
`python3-*` set. The 67th is **`docbook-xsl`**, and nothing was looking for it:
the triage category was defined as "`python3-*` whose largest shipped `.hud` is
under 5 KB", so a non-Python package with the same defect could not appear in it.

`docbook-xsl`'s `[install]` wrote every path as an absolute `/opt/hud` path with
no `$DESTDIR`, so the stylesheets went into the build container's own filesystem
instead of the staging tree. Different mistake from the Python ones — those omit
`--root=$DESTDIR` from pip — but the same outcome and the same invisibility: the
build succeeded, the test passed, and the package published.

Fixed in E7. The rebuilt package is **24.8 MB against 5 KB**.

## One more, and it is not empty enough to have been caught

**`meson` ships two files** — its bash and zsh completions — and no `meson`
program at all:

```
./opt/hud/share/bash-completion/completions/meson
./opt/hud/share/zsh/site-functions/_meson
```

Its `[install]` does have `--root=$DESTDIR`, so this is not the pip defect. The
`pip3 install --no-index --find-links dist` step installed nothing, and the two
`install -vDm644` lines after it are the only reason the package is not zero.
`meson` is in the PIP category and has not been converted yet; it needs the same
treatment as E5/E6, and the payload assertion in the E5 driver would have caught
it.

Nothing has noticed because **meson is one of the eleven genuine base-system
Python packages** in `/usr/lib/python3.13/site-packages`, dated 2025. Every
build that uses meson has been using that copy, not this package.

## The legitimately small

Four to five files or fewer, checked by hand and correct:

| Package | Files | Why |
|---|---|---|
| `dnsmasq` | 2 | one binary, one man page |
| `tree` | 2 | one binary, one man page |
| `ninja` | 3 | binary plus two completions |
| `util-macros` | 3 | pkg-config, aclocal macros, INSTALL |
| `libaio` | 3 | `.a`, `.so`, header |
| `libpciaccess` | 3 | pkg-config, `.so`, header |

## What to carry forward

**A green build proves nothing about whether a package contains anything.** The
66, `docbook-xsl` and `meson` all built, tested and published perfectly while
empty. Any rebuild driver should assert payload before publishing, as the E5/E6
driver now does, and G1 should run this sweep at the end.
