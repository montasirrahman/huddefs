# Conversion triage — all 245 packages

Generated 2026-09-01 by scanning the canonical
`huddefs/<package>/<package>.huddef` files. Classifies what stands between each
v1 definition and a v2 one that builds against the minimal rootfs.

A package can appear in several categories; the counts below therefore sum to
more than 245.

| Category | Packages | Meaning |
|---|---|---|
| **EASY** | **150** | No patches, no `pip3`, no network in build sections, and `[install]` stages everything under `$DESTDIR`. Mechanical conversion. |
| **PIP** | 72 | Runs `pip install` during the build. Forbidden under v2's network policy. |
| **SUSPECT-EMPTY** | 66 | A `python3-*` package whose shipped `.hud` is under 5 KB — almost certainly no payload. |
| **ABSOLUTE-PATH** | 24 | `[install]` writes outside `$DESTDIR`, or `[postinst]` creates files outside the package prefix. |
| **PATCH** | 4 | Applies one or more patches. |
| **NETWORK** | 2 | `wget` or `curl` inside a build section. |

**150 packages are EASY and nothing else.** 70 fall into more than one category.

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

# EASY — 150 packages

Mechanical conversion: add `Source-SHA256` from `docs/source-hashes.md`, move
build tools out of `Depends` into `Build-Depends`, set `Depends: auto`.

Ordering is alphabetical. The first 20 are the E3b batch.

| # | Package | Shipped size |
|---|---|---|
| 1 | `acl` | 116,972 |
| 2 | `alsa-lib` | 699,967 |
| 3 | `aom` | 7,664,018 |
| 4 | `attr` | 74,823 |
| 5 | `binutils` | 10,110,263 |
| 6 | `brotli` | 444,622 |
| 7 | `bzip2` | 532,159 |
| 8 | `cmake` | 34,315,454 |
| 9 | `cpio` | 399,800 |
| 10 | `cracklib` | 237,662 |
| 11 | `cups` | 6,489,225 |
| 12 | `curl` | 1,110,481 |
| 13 | `dav1d` | 1,009,472 |
| 14 | `dbus` | 668,219 |
| 15 | `dbus-python` | 163,559 |
| 16 | `dejavu-fonts` | 5,420,803 |
| 17 | `dmidecode` | 97,732 |
| 18 | `docbook` | 78,792 |
| 19 | `dtc` | 355,788 |
| 20 | `duktape` | 1,352,765 |
| 21 | `expat` | 142,607 |
| 22 | `flac` | 678,156 |
| 23 | `font-alias` | 2,976 |
| 24 | `font-util` | 38,483 |
| 25 | `fontconfig` | 1,380,511 |
| 26 | `freetype` | 613,118 |
| 27 | `fribidi` | 60,318 |
| 28 | `gdb` | 10,779,545 |
| 29 | `git` | 14,034,372 |
| 30 | `glib` | 7,292,801 |
| 31 | `gmp` | 463,716 |
| 32 | `gnutls` | 3,130,359 |
| 33 | `gobject-introspection` | 630,231 |
| 34 | `gperf` | 114,744 |
| 35 | `graphene` | 80,991 |
| 36 | `gstreamer` | 2,280,007 |
| 37 | `harfbuzz` | 2,007,582 |
| 38 | `icu` | 17,065,715 |
| 39 | `iptables` | 459,534 |
| 40 | `jansson` | 35,873 |
| 41 | `json-c` | 64,679 |
| 42 | `json-glib` | 179,680 |
| 43 | `kmod` | 163,287 |
| 44 | `lame` | 341,974 |
| 45 | `lcms2` | 297,803 |
| 46 | `libICE` | 96,462 |
| 47 | `libSM` | 57,806 |
| 48 | `libX11` | 2,184,681 |
| 49 | `libXau` | 11,719 |
| 50 | `libXdmcp` | 30,319 |
| 51 | `libXext` | 89,827 |
| 52 | `libXfixes` | 14,193 |
| 53 | `libXi` | 132,114 |
| 54 | `libXrandr` | 28,587 |
| 55 | `libXrender` | 30,492 |
| 56 | `libXt` | 514,712 |
| 57 | `libXtst` | 32,158 |
| 58 | `libaio` | 36,072 |
| 59 | `libarchive` | 616,322 |
| 60 | `libcap` | 97,203 |
| 61 | `libdrm` | 304,734 |
| 62 | `libedit` | 224,270 |
| 63 | `liberation-fonts` | 2,380,003 |
| 64 | `libev` | 128,396 |
| 65 | `libevent` | 462,299 |
| 66 | `libffi` | 47,422 |
| 67 | `libgcrypt` | 838,660 |
| 68 | `libgpg-error` | 397,103 |
| 69 | `libgudev` | 21,341 |
| 70 | `libibverbs` | 7,052,321 |
| 71 | `libidn2` | 183,195 |
| 72 | `libjpeg` | 1,003,870 |
| 73 | `libjpeg-turbo` | 1,021,933 |
| 74 | `libmnl` | 13,318 |
| 75 | `libndp` | 28,777 |
| 76 | `libnftnl` | 98,447 |
| 77 | `libnl` | 666,449 |
| 78 | `libogg` | 233,044 |
| 79 | `libpciaccess` | 25,356 |
| 80 | `libpng` | 383,084 |
| 81 | `libpsl` | 75,915 |
| 82 | `libseat` | 54,064 |
| 83 | `libseccomp` | 95,487 |
| 84 | `libslirp` | 224,545 |
| 85 | `libsndfile` | 425,195 |
| 86 | `libssh2` | 347,864 |
| 87 | `libtasn1` | 105,870 |
| 88 | `libtiff` | 1,816,372 |
| 89 | `libunistring` | 986,341 |
| 90 | `liburcu` | 259,953 |
| 91 | `libusb` | 81,157 |
| 92 | `libvorbis` | 989,321 |
| 93 | `libvpx` | 2,083,616 |
| 94 | `libwebp` | 871,455 |
| 95 | `libxcb` | 812,250 |
| 96 | `libxml2` | 1,402,382 |
| 97 | `libxslt` | 367,081 |
| 98 | `libyaml` | 112,025 |
| 99 | `libzip` | 183,738 |
| 100 | `lmdb` | 320,837 |
| 101 | `make-ca` | 15,193 |
| 102 | `mpc` | 92,693 |
| 103 | `mpfr` | 758,991 |
| 104 | `mtdev` | 20,822 |
| 105 | `nasm` | 1,338,767 |
| 106 | `ncurses` | 1,337,779 |
| 107 | `nettle` | 992,003 |
| 108 | `newt` | 154,330 |
| 109 | `nghttp2` | 472,800 |
| 110 | `ninja` | 3,307,652 |
| 111 | `nspr` | 1,074,631 |
| 112 | `numactl` | 139,238 |
| 113 | `oniguruma` | 244,359 |
| 114 | `openjdk` | 449,839,596 |
| 115 | `opus` | 533,002 |
| 116 | `pcre2` | 1,675,994 |
| 117 | `perl` | 20,533,259 |
| 118 | `pixman` | 506,732 |
| 119 | `polkit` | 205,393 |
| 120 | `popt` | 66,365 |
| 121 | `postgresql` | 11,226,991 |
| 122 | `pygobject` | 422,628 |
| 123 | `python3` | 80,818,114 |
| 124 | `rdma-core` | 6,838,089 |
| 125 | `readline` | 2,640,921 |
| 126 | `sanlock` | 831,886 |
| 127 | `sdl2` | 2,377,068 |
| 128 | `slang` | 1,113,862 |
| 129 | `sqlite` | 1,699,508 |
| 130 | `sudo` | 3,174,727 |
| 131 | `tree` | 44,353 |
| 132 | `util-macros` | 23,655 |
| 133 | `vala` | 3,599,955 |
| 134 | `valgrind` | 75,531,786 |
| 135 | `vim` | 14,053,783 |
| 136 | `wayland` | 240,393 |
| 137 | `which` | 17,671 |
| 138 | `x264` | 2,056,654 |
| 139 | `xbitmaps` | 25,636 |
| 140 | `xcb-proto` | 215,611 |
| 141 | `xkeyboard-config` | 1,731,619 |
| 142 | `xmlto` | 30,472 |
| 143 | `xorgproto` | 301,407 |
| 144 | `xtrans` | 47,990 |
| 145 | `xz` | 782,508 |
| 146 | `yajl` | 80,159 |
| 147 | `yasm` | 1,621,561 |
| 148 | `zip` | 307,605 |
| 149 | `zlib` | 158,488 |
| 150 | `zstd` | 1,560,640 |

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
