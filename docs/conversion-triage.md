# Conversion triage — all 245 packages

Generated 2026-09-01 by scanning the canonical
`huddefs/<package>/<package>.huddef` files. Classifies what stands between each
v1 definition and a v2 one that builds against the minimal rootfs.

A package can appear in several categories; the counts below therefore sum to
more than 245.

| Category | Packages | Meaning |
|---|---|---|
| **EASY** | **148** | No patches, no `pip3`, no network in build sections, `[install]` stages everything under `$DESTDIR`, and no undeclared inputs. Mechanical conversion. |
| **MULTI-SOURCE** | **2** | A build section reaches for an input the definition never declares — a second tarball, or state on the build host. |
| **PIP** | 72 | Runs `pip install` during the build. Forbidden under v2's network policy. |
| **SUSPECT-EMPTY** | 66 | A `python3-*` package whose shipped `.hud` is under 5 KB — almost certainly no payload. |
| **ABSOLUTE-PATH** | 24 | `[install]` writes outside `$DESTDIR`, or `[postinst]` creates files outside the package prefix. |
| **PATCH** | 4 | Applies one or more patches. |
| **NETWORK** | 2 | `wget` or `curl` inside a build section. |

**148 packages are EASY and nothing else.** 70 fall into more than one category.

## How each category was decided

- **PIP** — `pip install` / `pip3 install` anywhere in `[configure]`, `[build]`,
  `[install]` or `[check]`.
- **NETWORK** — `wget` or `curl` in those same sections. Note `wget` is not
  installed on any machine, so these have been failing silently rather than
  downloading anything.
- **PATCH** — a `Patches:` header, or a `patch -` invocation in a build section.
- **ABSOLUTE-PATH** — two different defects under one label:
  - in `[install]`, any write to an absolute path with no `$DESTDIR` — the
    staged tree will not contain the file, so it never ships and the write lands
    on the build server instead;
  - in `[postinst]`, creating a file **outside** `/opt/hud` — it will not appear
    in `FILES` and `hud remove` will not clean it up.

  `chmod`/`chown`/`chgrp` on the package's own `/opt/hud` files in `[postinst]`
  are **not** flagged: setuid bits cannot survive a tar, so fixing them after
  extraction is legitimate.
- **MULTI-SOURCE** — a build section extracts an archive whose name does not
  match `Source:`, runs a VCS checkout, or reads from a path on the build host
  such as `/var/hud-build/staging`. Added after `alsa-lib` was classified EASY
  and then failed on an undeclared second tarball; the whole EASY set was
  rescanned for the pattern.

- **SUSPECT-EMPTY** — `python3-*` whose largest shipped `.hud` in `pool/` is
  under 5 KB. `python3-distlib` at 676,946 bytes is the correct reference and is
  deliberately *not* in this category.

### One important non-defect

A plain `make install` with no explicit `DESTDIR=` is **not** flagged. `hud-build`
exports `DESTDIR` into the build environment and GNU make honours it, so those
stage correctly. This was verified with a fixture: v1 libpng's `make install`
line worked; only its hardcoded `/usr/share/doc` path was broken.

## Category overlaps

- PIP + SUSPECT-EMPTY — 65
- ABSOLUTE-PATH + PATCH — 1
- NETWORK + PATCH — 1
- ABSOLUTE-PATH + PIP — 1
- PATCH + PIP + SUSPECT-EMPTY — 1
- ABSOLUTE-PATH + NETWORK + PATCH + PIP — 1

### qemu is the worst case

`qemu` is the only package in **four** categories at once — ABSOLUTE-PATH,
NETWORK, PATCH and PIP — and the only one anywhere in the tree whose patch is
guarded by `|| true`:

```bash
pip3 install distlib --break-system-packages 2>/dev/null || pip3 install distlib
wget -nc https://...qemu-10.0.3-python_fixes-1.patch ... 2>/dev/null || true
patch -Np1 -i ../qemu-10.0.3-python_fixes-1.patch || true
```

With `wget` absent the download fails, `|| true` swallows it, the patch has no
file, `|| true` swallows that too, and the build reports success. The shipped
qemu is almost certainly unpatched. Leave it until last.

## Already converted

| Package | Status |
|---|---|
| `libpng` | v2, builds and tests green against the minimal rootfs |
| `zlib` | v2, builds and tests green against the minimal rootfs |

---

# EASY — 148 packages

Mechanical conversion: add `Source-SHA256` from `docs/source-hashes.md`, move
build tools out of `Depends` into `Build-Depends`, set `Depends: auto`.

Ordering is alphabetical. The first 20 are the E3b batch.

| # | Package | Shipped size |
|---|---|---|
| 1 | `acl` | 116,972 |
| 2 | `aom` | 7,664,018 |
| 3 | `attr` | 74,823 |
| 4 | `binutils` | 10,110,263 |
| 5 | `brotli` | 444,622 |
| 6 | `bzip2` | 532,159 |
| 7 | `cmake` | 34,315,454 |
| 8 | `cpio` | 399,800 |
| 9 | `cracklib` | 237,662 |
| 10 | `cups` | 6,489,225 |
| 11 | `curl` | 1,110,481 |
| 12 | `dav1d` | 1,009,472 |
| 13 | `dbus` | 668,219 |
| 14 | `dbus-python` | 163,559 |
| 15 | `dejavu-fonts` | 5,420,803 |
| 16 | `dmidecode` | 97,732 |
| 17 | `dtc` | 355,788 |
| 18 | `duktape` | 1,352,765 |
| 19 | `expat` | 142,607 |
| 20 | `flac` | 678,156 |
| 21 | `font-alias` | 2,976 |
| 22 | `font-util` | 38,483 |
| 23 | `fontconfig` | 1,380,511 |
| 24 | `freetype` | 613,118 |
| 25 | `fribidi` | 60,318 |
| 26 | `gdb` | 10,779,545 |
| 27 | `git` | 14,034,372 |
| 28 | `glib` | 7,292,801 |
| 29 | `gmp` | 463,716 |
| 30 | `gnutls` | 3,130,359 |
| 31 | `gobject-introspection` | 630,231 |
| 32 | `gperf` | 114,744 |
| 33 | `graphene` | 80,991 |
| 34 | `gstreamer` | 2,280,007 |
| 35 | `harfbuzz` | 2,007,582 |
| 36 | `icu` | 17,065,715 |
| 37 | `iptables` | 459,534 |
| 38 | `jansson` | 35,873 |
| 39 | `json-c` | 64,679 |
| 40 | `json-glib` | 179,680 |
| 41 | `kmod` | 163,287 |
| 42 | `lame` | 341,974 |
| 43 | `lcms2` | 297,803 |
| 44 | `libICE` | 96,462 |
| 45 | `libSM` | 57,806 |
| 46 | `libX11` | 2,184,681 |
| 47 | `libXau` | 11,719 |
| 48 | `libXdmcp` | 30,319 |
| 49 | `libXext` | 89,827 |
| 50 | `libXfixes` | 14,193 |
| 51 | `libXi` | 132,114 |
| 52 | `libXrandr` | 28,587 |
| 53 | `libXrender` | 30,492 |
| 54 | `libXt` | 514,712 |
| 55 | `libXtst` | 32,158 |
| 56 | `libaio` | 36,072 |
| 57 | `libarchive` | 616,322 |
| 58 | `libcap` | 97,203 |
| 59 | `libdrm` | 304,734 |
| 60 | `libedit` | 224,270 |
| 61 | `liberation-fonts` | 2,380,003 |
| 62 | `libev` | 128,396 |
| 63 | `libevent` | 462,299 |
| 64 | `libffi` | 47,422 |
| 65 | `libgcrypt` | 838,660 |
| 66 | `libgpg-error` | 397,103 |
| 67 | `libgudev` | 21,341 |
| 68 | `libibverbs` | 7,052,321 |
| 69 | `libidn2` | 183,195 |
| 70 | `libjpeg` | 1,003,870 |
| 71 | `libjpeg-turbo` | 1,021,933 |
| 72 | `libmnl` | 13,318 |
| 73 | `libndp` | 28,777 |
| 74 | `libnftnl` | 98,447 |
| 75 | `libnl` | 666,449 |
| 76 | `libogg` | 233,044 |
| 77 | `libpciaccess` | 25,356 |
| 78 | `libpng` | 383,084 |
| 79 | `libpsl` | 75,915 |
| 80 | `libseat` | 54,064 |
| 81 | `libseccomp` | 95,487 |
| 82 | `libslirp` | 224,545 |
| 83 | `libsndfile` | 425,195 |
| 84 | `libssh2` | 347,864 |
| 85 | `libtasn1` | 105,870 |
| 86 | `libtiff` | 1,816,372 |
| 87 | `libunistring` | 986,341 |
| 88 | `liburcu` | 259,953 |
| 89 | `libusb` | 81,157 |
| 90 | `libvorbis` | 989,321 |
| 91 | `libvpx` | 2,083,616 |
| 92 | `libwebp` | 871,455 |
| 93 | `libxcb` | 812,250 |
| 94 | `libxml2` | 1,402,382 |
| 95 | `libxslt` | 367,081 |
| 96 | `libyaml` | 112,025 |
| 97 | `libzip` | 183,738 |
| 98 | `lmdb` | 320,837 |
| 99 | `make-ca` | 15,193 |
| 100 | `mpc` | 92,693 |
| 101 | `mpfr` | 758,991 |
| 102 | `mtdev` | 20,822 |
| 103 | `nasm` | 1,338,767 |
| 104 | `ncurses` | 1,337,779 |
| 105 | `nettle` | 992,003 |
| 106 | `newt` | 154,330 |
| 107 | `nghttp2` | 472,800 |
| 108 | `ninja` | 3,307,652 |
| 109 | `nspr` | 1,074,631 |
| 110 | `numactl` | 139,238 |
| 111 | `oniguruma` | 244,359 |
| 112 | `openjdk` | 449,839,596 |
| 113 | `opus` | 533,002 |
| 114 | `pcre2` | 1,675,994 |
| 115 | `perl` | 20,533,259 |
| 116 | `pixman` | 506,732 |
| 117 | `polkit` | 205,393 |
| 118 | `popt` | 66,365 |
| 119 | `postgresql` | 11,226,991 |
| 120 | `pygobject` | 422,628 |
| 121 | `python3` | 80,818,114 |
| 122 | `rdma-core` | 6,838,089 |
| 123 | `readline` | 2,640,921 |
| 124 | `sanlock` | 831,886 |
| 125 | `sdl2` | 2,377,068 |
| 126 | `slang` | 1,113,862 |
| 127 | `sqlite` | 1,699,508 |
| 128 | `sudo` | 3,174,727 |
| 129 | `tree` | 44,353 |
| 130 | `util-macros` | 23,655 |
| 131 | `vala` | 3,599,955 |
| 132 | `valgrind` | 75,531,786 |
| 133 | `vim` | 14,053,783 |
| 134 | `wayland` | 240,393 |
| 135 | `which` | 17,671 |
| 136 | `x264` | 2,056,654 |
| 137 | `xbitmaps` | 25,636 |
| 138 | `xcb-proto` | 215,611 |
| 139 | `xkeyboard-config` | 1,731,619 |
| 140 | `xmlto` | 30,472 |
| 141 | `xorgproto` | 301,407 |
| 142 | `xtrans` | 47,990 |
| 143 | `xz` | 782,508 |
| 144 | `yajl` | 80,159 |
| 145 | `yasm` | 1,621,561 |
| 146 | `zip` | 307,605 |
| 147 | `zlib` | 158,488 |
| 148 | `zstd` | 1,560,640 |
---

# ABSOLUTE-PATH — 24 packages

Each needs a judgement call about where the file belongs, so none is mechanical.

| Package | Also in | Evidence |
|---|---|---|
| `cyrus-sasl` | — | `[install]` `install -v -dm755                          /usr/share/doc/cyrus-sasl-2` |
| `dhcpcd` | — | `[postinst]` `install -v -m755 -d /var/lib/dhcpcd` |
| `dnsmasq` | — | `[postinst]` `install -vdm755 /etc/dnsmasq.d` |
| `docbook-xsl` | PATCH | `[install]` `install -v -m755 -d /opt/hud/share/xml/docbook/xsl-stylesheets-nons-1.` |
| `firewalld` | — | `[postinst]` `install -vdm755 /etc/firewalld` |
| `glusterfs` | PIP | `[postinst]` `mkdir -p /var/lib/glusterd` |
| `gperftools` | — | `[postinst]` `ln -sf /usr/lib64/libtcmalloc.so.4 /usr/lib64/libtcmalloc.so` |
| `java-bin` | — | `[postinst]` `ln -sfv /etc/pki/tls/java/cacerts /opt/jdk/lib/security/cacerts` |
| `libtirpc` | — | `[postinst]` `ln -sf /usr/lib64/libtirpc.so.3 /usr/lib64/libtirpc.so` |
| `libvirt` | — | `[postinst]` `install -vdm755 /etc/libvirt` |
| `linux-pam` | — | `[postinst]` `install -vdm755 /etc/pam.d` |
| `networkmanager` | — | `[postinst]` `install -vdm755 /etc/NetworkManager/conf.d` |
| `nftables` | — | `[postinst]` `install -vdm755 /etc/nftables` |
| `nodejs` | — | `[install]` `ln -sf node /usr/share/doc/node-22.18.0` |
| `openldap` | — | `[install]` `install -v -dm700 -o ldap -g ldap /var/lib/openldap     &&` |
| `openssl` | — | `[postinst]` `ln -sf /etc/pki/tls/certs/ca-bundle.crt /opt/hud/etc/ssl/cert.pem 2>/d` |
| `p11-kit` | — | `[install]` `ln -sfv /opt/hud/libexec/p11-kit/trust-extract-compat \` |
| `postgresql-ha` | — | `[install]` `ExecStartPre=/bin/mkdir -p /run/postgresql` |
| `postgresql-ldap` | — | `[install]` `ExecStartPre=/bin/mkdir -p /run/postgresql` |
| `postgresql-ldap-ha` | — | `[install]` `ExecStartPre=/bin/mkdir -p /run/postgresql` |
| `python3-py3c` | — | `[install]` `make prefix=/opt/hud install` |
| `qemu` | NETWORK, PATCH, PIP | `[postinst]` `install -vdm755 /etc/qemu` |
| `util-linux` | — | `[postinst]` `mkdir -pv /var/lib/hwclock 2>/dev/null \|\| true` |
| `wpa_supplicant` | — | `[postinst]` `install -v -dm755 /etc/wpa_supplicant` |

---

# PIP — 72 packages

Every one needs its `pip install` replaced by a `Build-Depends` entry, and most also need `--root=$DESTDIR`. Heavily overlapping with SUSPECT-EMPTY.

| Package | Also in | Evidence |
|---|---|---|
| `glusterfs` | ABSOLUTE-PATH |  |
| `meson` | — |  |
| `python-setuptools` | — |  |
| `python3-alabaster` | SUSPECT-EMPTY |  |
| `python3-asciidoc` | SUSPECT-EMPTY |  |
| `python3-attrs` | SUSPECT-EMPTY |  |
| `python3-babel` | SUSPECT-EMPTY |  |
| `python3-build` | SUSPECT-EMPTY |  |
| `python3-cachecontrol` | SUSPECT-EMPTY |  |
| `python3-certifi` | SUSPECT-EMPTY |  |
| `python3-chardet` | SUSPECT-EMPTY |  |
| `python3-charset-normalizer` | SUSPECT-EMPTY |  |
| `python3-commonmark` | SUSPECT-EMPTY |  |
| `python3-cssselect` | SUSPECT-EMPTY |  |
| `python3-cython` | SUSPECT-EMPTY |  |
| `python3-distlib` | — |  |
| `python3-docutils` | SUSPECT-EMPTY |  |
| `python3-doxypypy` | SUSPECT-EMPTY |  |
| `python3-doxyqml` | SUSPECT-EMPTY |  |
| `python3-editables` | SUSPECT-EMPTY |  |
| `python3-gi-docgen` | SUSPECT-EMPTY |  |
| `python3-hatch-fancy-pypi-readme` | SUSPECT-EMPTY |  |
| `python3-hatch-vcs` | SUSPECT-EMPTY |  |
| `python3-hatchling` | SUSPECT-EMPTY |  |
| `python3-html5lib` | SUSPECT-EMPTY |  |
| `python3-idna` | SUSPECT-EMPTY |  |
| `python3-imagesize` | SUSPECT-EMPTY |  |
| `python3-iniconfig` | SUSPECT-EMPTY |  |
| `python3-lxml` | SUSPECT-EMPTY |  |
| `python3-mako` | SUSPECT-EMPTY |  |
| `python3-markdown` | SUSPECT-EMPTY |  |
| `python3-meson-python` | SUSPECT-EMPTY |  |
| `python3-msgpack` | SUSPECT-EMPTY |  |
| `python3-numpy` | SUSPECT-EMPTY |  |
| `python3-pathspec` | SUSPECT-EMPTY |  |
| `python3-pluggy` | SUSPECT-EMPTY |  |
| `python3-ply` | SUSPECT-EMPTY |  |
| `python3-psutil` | SUSPECT-EMPTY |  |
| `python3-pygdbmi` | SUSPECT-EMPTY |  |
| `python3-pygments` | SUSPECT-EMPTY |  |
| `python3-pyparsing` | SUSPECT-EMPTY |  |
| `python3-pyproject-hooks` | SUSPECT-EMPTY |  |
| `python3-pyproject-metadata` | SUSPECT-EMPTY |  |
| `python3-pyserial` | SUSPECT-EMPTY |  |
| `python3-pytest` | SUSPECT-EMPTY |  |
| `python3-pytz` | SUSPECT-EMPTY |  |
| `python3-pyxdg` | SUSPECT-EMPTY |  |
| `python3-pyyaml` | SUSPECT-EMPTY |  |
| `python3-recommonmark` | SUSPECT-EMPTY |  |
| `python3-requests` | PATCH, SUSPECT-EMPTY |  |
| `python3-roman-numerals-py` | SUSPECT-EMPTY |  |
| `python3-scour` | SUSPECT-EMPTY |  |
| `python3-sentry-sdk` | SUSPECT-EMPTY |  |
| `python3-setuptools-scm` | SUSPECT-EMPTY |  |
| `python3-six` | SUSPECT-EMPTY |  |
| `python3-smartypants` | SUSPECT-EMPTY |  |
| `python3-snowballstemmer` | SUSPECT-EMPTY |  |
| `python3-sphinx` | SUSPECT-EMPTY |  |
| `python3-sphinx-rtd-theme` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-applehelp` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-devhelp` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-htmlhelp` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-jquery` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-jsmath` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-qthelp` | SUSPECT-EMPTY |  |
| `python3-sphinxcontrib-serializinghtml` | SUSPECT-EMPTY |  |
| `python3-trove-classifiers` | SUSPECT-EMPTY |  |
| `python3-typogrify` | SUSPECT-EMPTY |  |
| `python3-urllib3` | SUSPECT-EMPTY |  |
| `python3-webencodings` | SUSPECT-EMPTY |  |
| `qemu` | ABSOLUTE-PATH, NETWORK, PATCH |  |
| `systemd` | — |  |

---

# SUSPECT-EMPTY — 66 packages

Shipped `.hud` under 5 KB. These are the empty packages from `CLAUDE.md` item 4.

| Package | Also in | Evidence |
|---|---|---|
| `python3-alabaster` | PIP | 748 bytes |
| `python3-asciidoc` | PIP | 754 bytes |
| `python3-attrs` | PIP | 782 bytes |
| `python3-babel` | PIP | 765 bytes |
| `python3-build` | PIP | 759 bytes |
| `python3-cachecontrol` | PIP | 775 bytes |
| `python3-certifi` | PIP | 760 bytes |
| `python3-chardet` | PIP | 750 bytes |
| `python3-charset-normalizer` | PIP | 777 bytes |
| `python3-commonmark` | PIP | 749 bytes |
| `python3-cssselect` | PIP | 757 bytes |
| `python3-cython` | PIP | 753 bytes |
| `python3-docutils` | PIP | 768 bytes |
| `python3-doxypypy` | PIP | 751 bytes |
| `python3-doxyqml` | PIP | 765 bytes |
| `python3-editables` | PIP | 750 bytes |
| `python3-gi-docgen` | PIP | 791 bytes |
| `python3-hatch-fancy-pypi-readme` | PIP | 765 bytes |
| `python3-hatch-vcs` | PIP | 772 bytes |
| `python3-hatchling` | PIP | 798 bytes |
| `python3-html5lib` | PIP | 770 bytes |
| `python3-idna` | PIP | 770 bytes |
| `python3-imagesize` | PIP | 752 bytes |
| `python3-iniconfig` | PIP | 769 bytes |
| `python3-lxml` | PIP | 752 bytes |
| `python3-mako` | PIP | 759 bytes |
| `python3-markdown` | PIP | 752 bytes |
| `python3-meson-python` | PIP | 780 bytes |
| `python3-msgpack` | PIP | 757 bytes |
| `python3-numpy` | PIP | 794 bytes |
| `python3-pathspec` | PIP | 760 bytes |
| `python3-pluggy` | PIP | 773 bytes |
| `python3-ply` | PIP | 753 bytes |
| `python3-psutil` | PIP | 765 bytes |
| `python3-pygdbmi` | PIP | 754 bytes |
| `python3-pygments` | PIP | 771 bytes |
| `python3-pyparsing` | PIP | 761 bytes |
| `python3-pyproject-hooks` | PIP | 762 bytes |
| `python3-pyproject-metadata` | PIP | 753 bytes |
| `python3-pyserial` | PIP | 762 bytes |
| `python3-pytest` | PIP | 772 bytes |
| `python3-pytz` | PIP | 748 bytes |
| `python3-pyxdg` | PIP | 761 bytes |
| `python3-pyyaml` | PIP | 759 bytes |
| `python3-recommonmark` | PIP | 786 bytes |
| `python3-requests` | PATCH, PIP | 786 bytes |
| `python3-roman-numerals-py` | PIP | 760 bytes |
| `python3-scour` | PIP | 748 bytes |
| `python3-sentry-sdk` | PIP | 770 bytes |
| `python3-setuptools-scm` | PIP | 769 bytes |
| `python3-six` | PIP | 746 bytes |
| `python3-smartypants` | PIP | 769 bytes |
| `python3-snowballstemmer` | PIP | 759 bytes |
| `python3-sphinx` | PIP | 893 bytes |
| `python3-sphinx-rtd-theme` | PIP | 775 bytes |
| `python3-sphinxcontrib-applehelp` | PIP | 761 bytes |
| `python3-sphinxcontrib-devhelp` | PIP | 758 bytes |
| `python3-sphinxcontrib-htmlhelp` | PIP | 761 bytes |
| `python3-sphinxcontrib-jquery` | PIP | 768 bytes |
| `python3-sphinxcontrib-jsmath` | PIP | 757 bytes |
| `python3-sphinxcontrib-qthelp` | PIP | 759 bytes |
| `python3-sphinxcontrib-serializinghtml` | PIP | 761 bytes |
| `python3-trove-classifiers` | PIP | 756 bytes |
| `python3-typogrify` | PIP | 769 bytes |
| `python3-urllib3` | PIP | 763 bytes |
| `python3-webencodings` | PIP | 760 bytes |

---

# NETWORK — 2 packages

Network access inside a build section.

| Package | Also in | Evidence |
|---|---|---|
| `giflib` | PATCH |  |
| `qemu` | ABSOLUTE-PATH, PATCH, PIP |  |

---

# PATCH — 4 packages

Patches must move into `patches/` and apply cleanly; a failure must be fatal.

| Package | Also in | Evidence |
|---|---|---|
| `docbook-xsl` | ABSOLUTE-PATH |  |
| `giflib` | NETWORK |  |
| `python3-requests` | PIP, SUSPECT-EMPTY |  |
| `qemu` | ABSOLUTE-PATH, NETWORK, PIP | **patch guarded by `|| true`** |

---

# MULTI-SOURCE — 2 packages

A build section reaches for an input the definition never declares. These are the
reason `Source-SHA256` exists: an undeclared download or an undeclared file on
the build host is exactly what it cannot protect you from.

Found by scanning every EASY package for: an archive name that does not match
`Source:`, `git clone`/`svn`/`hg`, extraction commands, and reads from
`/var/hud-build` or `/var/www/hud-repo`.

| Package | Section | What it reaches for |
|---|---|---|
| `alsa-lib` | `[install]` | `tar -C /usr/share/alsa --strip-components=1 -xf ../alsa-ucm-conf-1.2.14.tar.bz2` — a second upstream release, and note the destination is outside `$DESTDIR` too |
| `docbook` | `[install]` | `FOUND=$(find /var/hud-build/staging -name "docbook.cat" ...)` — searches the build host's leftover staging directories for a file no definition produces |

`docbook` is the worse of the two. It depends on state left behind by previous
builds on one particular machine, so it cannot build on a clean host at all —
and against the minimal rootfs `/var/hud-build/staging` does not exist.

One false positive was rejected during the scan: `libarchive`'s
`ln -sfv bsdunzip $DESTDIR/opt/hud/bin/unzip` matched an early version of the
extraction pattern. `unzip` there is the name of a symlink being created, not a
command. The scanner now requires the tool to be in command position.
