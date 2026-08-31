# Consolidation manifest

Generated 2026-08-31. Records where every file in `huddefs/` came from, so the
consolidation can be audited without re-running it. Source paths are relative to
`/var/www/hud-repo/` on bf-repo.

- **245** packages consolidated, one `<package>.huddef` each
- **96** needed a tiebreak; **134** `.alt` files were kept for review
- Canonical copy is always the archive in `pool/main/<letter>/<name>/` — the
  definition that built the shipped `.hud`. For the six packages with two
  archived versions, the canonical is the version listed first in
  `packages.list`, which is the current published one.
- Every canonical file was verified byte-identical to its pool source after copying.

## Packages that needed a tiebreak (96)

| Package | Version | Canonical source | Copies in `sources/definitions/` | `.alt` files |
|---|---|---|---|---|
| `alsa-lib` | 1.2.14 | `pool/main/a/alsa-lib/alsa-lib-1.2.14.huddef` | 3 | 1 |
| `bzip2` | 1.0.8 | `pool/main/b/bzip2/bzip2-1.0.8.huddef` | 3 | 1 |
| `cmake` | 4.1.0 | `pool/main/c/cmake/cmake-4.1.0.huddef` | 3 | 2 |
| `cups` | 2.4.12 | `pool/main/c/cups/cups-2.4.12.huddef` | 2 | 1 |
| `curl` | 8.15.0 | `pool/main/c/curl/curl-8.15.0.huddef` | 4 | 2 |
| `cyrus-sasl` | 2.1.28 | `pool/main/c/cyrus-sasl/cyrus-sasl-2.1.28.huddef` | 3 | 1 |
| `dbus` | 1.16.2 | `pool/main/d/dbus/dbus-1.16.2.huddef` | 4 | 3 |
| `dtc` | 1.7.2 | `pool/main/d/dtc/dtc-1.7.2.huddef` | 3 | 2 |
| `duktape` | 2.7.0 | `pool/main/d/duktape/duktape-2.7.0.huddef` | 3 | 1 |
| `expat` | 2.7.1 | `pool/main/e/expat/expat-2.7.1.huddef` | 5 | 1 |
| `firewalld` | 2.3.2 | `pool/main/f/firewalld/firewalld-2.3.2.huddef` | 3 | 1 |
| `fontconfig` | 2.17.1 | `pool/main/f/fontconfig/fontconfig-2.17.1.huddef` | 3 | 1 |
| `freetype` | 2.14.0 | `pool/main/f/freetype/freetype-2.14.0.huddef` | 2 | 1 |
| `fribidi` | 1.0.16 | `pool/main/f/fribidi/fribidi-1.0.16.huddef` | 3 | 1 |
| `giflib` | 5.2.2 | `pool/main/g/giflib/giflib-5.2.2.huddef` | 2 | 1 |
| `glib` | 2.84.4 | `pool/main/g/glib/glib-2.84.4.huddef` | 4 | 2 |
| `glusterfs` | 11.1 | `pool/main/g/glusterfs/glusterfs-11.1.huddef` | 3 | 1 |
| `gnutls` | 3.8.10 | `pool/main/g/gnutls/gnutls-3.8.10.huddef` | 3 | 2 |
| `harfbuzz` | 11.4.1 | `pool/main/h/harfbuzz/harfbuzz-11.4.1.huddef` | 4 | 2 |
| `icu` | 77.1 | `pool/main/i/icu/icu-77.1.huddef` | 3 | 2 |
| `iptables` | 1.8.11 | `pool/main/i/iptables/iptables-1.8.11.huddef` | 3 | 1 |
| `json-c` | 0.18 | `pool/main/j/json-c/json-c-0.18.huddef` | 2 | 1 |
| `json-glib` | 1.10.6 | `pool/main/j/json-glib/json-glib-1.10.6.huddef` | 3 | 2 |
| `kmod` | 34 | `pool/main/k/kmod/kmod-34.huddef` | 2 | 1 |
| `libICE` | 1.1.2 | `pool/main/l/libICE/libICE-1.1.2.huddef` | 2 | 1 |
| `libSM` | 1.2.6 | `pool/main/l/libSM/libSM-1.2.6.huddef` | 2 | 1 |
| `libX11` | 1.8.12 | `pool/main/l/libX11/libX11-1.8.12.huddef` | 2 | 1 |
| `libXau` | 1.0.12 | `pool/main/l/libXau/libXau-1.0.12.huddef` | 2 | 1 |
| `libXdmcp` | 1.1.5 | `pool/main/l/libXdmcp/libXdmcp-1.1.5.huddef` | 2 | 1 |
| `libXext` | 1.3.6 | `pool/main/l/libXext/libXext-1.3.6.huddef` | 2 | 1 |
| `libXfixes` | 6.0.1 | `pool/main/l/libXfixes/libXfixes-6.0.1.huddef` | 2 | 1 |
| `libXi` | 1.8.2 | `pool/main/l/libXi/libXi-1.8.2.huddef` | 2 | 1 |
| `libXrandr` | 1.5.4 | `pool/main/l/libXrandr/libXrandr-1.5.4.huddef` | 2 | 1 |
| `libXrender` | 0.9.12 | `pool/main/l/libXrender/libXrender-0.9.12.huddef` | 2 | 1 |
| `libXt` | 1.3.1 | `pool/main/l/libXt/libXt-1.3.1.huddef` | 2 | 1 |
| `libXtst` | 1.2.5 | `pool/main/l/libXtst/libXtst-1.2.5.huddef` | 2 | 1 |
| `libaio` | 0.3.113 | `pool/main/l/libaio/libaio-0.3.113.huddef` | 2 | 1 |
| `libdrm` | 2.4.124 | `pool/main/l/libdrm/libdrm-2.4.124.huddef` | 4 | 1 |
| `libevent` | 2.1.12 | `pool/main/l/libevent/libevent-2.1.12.huddef` | 2 | 1 |
| `libffi` | 3.4.8 | `pool/main/l/libffi/libffi-3.4.8.huddef` | 4 | 1 |
| `libgcrypt` | 1.11.2 | `pool/main/l/libgcrypt/libgcrypt-1.11.2.huddef` | 2 | 1 |
| `libgpg-error` | 1.55 | `pool/main/l/libgpg-error/libgpg-error-1.55.huddef` | 2 | 1 |
| `libgudev` | 238 | `pool/main/l/libgudev/libgudev-238.huddef` | 2 | 1 |
| `libidn2` | 2.3.8 | `pool/main/l/libidn2/libidn2-2.3.8.huddef` | 3 | 2 |
| `libjpeg` | 3.0.1 | `pool/main/l/libjpeg/libjpeg-3.0.1.huddef` | 2 | 1 |
| `libndp` | 1.9 | `pool/main/l/libndp/libndp-1.9.huddef` | 3 | 2 |
| `libpng` | 1.6.50 | `pool/main/l/libpng/libpng-1.6.50.huddef` | 3 | 1 |
| `libpsl` | 0.21.5 | `pool/main/l/libpsl/libpsl-0.21.5.huddef` | 3 | 2 |
| `libslirp` | 4.9.1 | `pool/main/l/libslirp/libslirp-4.9.1.huddef` | 4 | 3 |
| `libsndfile` | 1.2.2 | `pool/main/l/libsndfile/libsndfile-1.2.2.huddef` | 2 | 1 |
| `libtasn1` | 4.20.0 | `pool/main/l/libtasn1/libtasn1-4.20.0.huddef` | 3 | 2 |
| `libtiff` | 4.7.0 | `pool/main/l/libtiff/libtiff-4.7.0.huddef` | 3 | 1 |
| `libtirpc` | 1.3.7 | `pool/main/l/libtirpc/libtirpc-1.3.7.huddef` | 3 | 2 |
| `libunistring` | 1.3 | `pool/main/l/libunistring/libunistring-1.3.huddef` | 3 | 2 |
| `libvirt` | 10.10.0 | `pool/main/l/libvirt/libvirt-10.10.0.huddef` | 5 | 3 |
| `libvorbis` | 1.3.7 | `pool/main/l/libvorbis/libvorbis-1.3.7.huddef` | 2 | 1 |
| `libxcb` | 1.17.0 | `pool/main/l/libxcb/libxcb-1.17.0.huddef` | 2 | 1 |
| `libxml2` | 2.14.5 | `pool/main/l/libxml2/libxml2-2.14.5.huddef` | 3 | 2 |
| `libxslt` | 1.1.43 | `pool/main/l/libxslt/libxslt-1.1.43.huddef` | 3 | 1 |
| `linux-pam` | 1.7.1 | `pool/main/l/linux-pam/linux-pam-1.7.1.huddef` | 5 | 3 |
| `make-ca` | 1.16.1 | `pool/main/m/make-ca/make-ca-1.16.1.huddef` | 3 | 2 |
| `meson` | 1.8.3 | `pool/main/m/meson/meson-1.8.3.huddef` | 3 | 2 |
| `ncurses` | 6.5.20250809 | `pool/main/n/ncurses/ncurses-6.5.20250809.huddef` | 2 | 1 |
| `nettle` | 3.10.2 | `pool/main/n/nettle/nettle-3.10.2.huddef` | 3 | 2 |
| `networkmanager` | 1.54.0 | `pool/main/n/networkmanager/networkmanager-1.54.0.huddef` | 5 | 3 |
| `newt` | 0.52.25 | `pool/main/n/newt/newt-0.52.25.huddef` | 3 | 1 |
| `nftables` | 1.1.1 | `pool/main/n/nftables/nftables-1.1.1.huddef` | 3 | 2 |
| `nghttp2` | 1.66.0 | `pool/main/n/nghttp2/nghttp2-1.66.0.huddef` | 3 | 1 |
| `ninja` | 1.13.1 | `pool/main/n/ninja/ninja-1.13.1.huddef` | 3 | 2 |
| `nspr` | 4.37 | `pool/main/n/nspr/nspr-4.37.huddef` | 3 | 2 |
| `openjdk` | 24.0.2 | `pool/main/o/openjdk/openjdk-24.0.2.huddef` | 3 | 1 |
| `openldap` | 2.6.10 | `pool/main/o/openldap/openldap-2.6.10.huddef` | 3 | 1 |
| `openssl` | 3.5.2 | `pool/main/o/openssl/openssl-3.5.2.huddef` | 2 | 1 |
| `p11-kit` | 0.25.5 | `pool/main/p/p11-kit/p11-kit-0.25.5.huddef` | 3 | 2 |
| `pcre2` | 10.45 | `pool/main/p/pcre2/pcre2-10.45.huddef` | 4 | 2 |
| `perl` | 5.42.0 | `pool/main/p/perl/perl-5.42.0.huddef` | 2 | 1 |
| `pixman` | 0.46.4 | `pool/main/p/pixman/pixman-0.46.4.huddef` | 5 | 2 |
| `polkit` | 126 | `pool/main/p/polkit/polkit-126.huddef` | 4 | 2 |
| `popt` | 1.19 | `pool/main/p/popt/popt-1.19.huddef` | 3 | 1 |
| `postgresql` | 17.6 | `pool/main/p/postgresql/postgresql-17.6.huddef` | 3 | 1 |
| `python-setuptools` | 80.9.0 | `pool/main/p/python-setuptools/python-setuptools-80.9.0.huddef` | 2 | 1 |
| `python3` | 3.13.7 | `pool/main/p/python3/python3-3.13.7.huddef` | 2 | 1 |
| `qemu` | 10.0.3 | `pool/main/q/qemu/qemu-10.0.3.huddef` | 5 | 2 |
| `readline` | 8.3 | `pool/main/r/readline/readline-8.3.huddef` | 2 | 1 |
| `sanlock` | 3.9.5 | `pool/main/s/sanlock/sanlock-3.9.5.huddef` | 3 | 1 |
| `sdl2` | 2.32.8 | `pool/main/s/sdl2/sdl2-2.32.8.huddef` | 3 | 1 |
| `slang` | 2.3.3 | `pool/main/s/slang/slang-2.3.3.huddef` | 3 | 1 |
| `sqlite` | 3.50.4 | `pool/main/s/sqlite/sqlite-3.50.4.huddef` | 3 | 1 |
| `sudo` | 1.9.17p2 | `pool/main/s/sudo/sudo-1.9.17p2.huddef` | 5 | 2 |
| `systemd` | 257.8 | `pool/main/s/systemd/systemd-257.8.huddef` | 3 | 1 |
| `tree` | 2.2.1 | `pool/main/t/tree/tree-2.2.1.huddef` | 3 | 1 |
| `util-macros` | 1.20.2 | `pool/main/u/util-macros/util-macros-1.20.2.huddef` | 3 | 1 |
| `vala` | 0.56.18 | `pool/main/v/vala/vala-0.56.18.huddef` | 3 | 1 |
| `wayland` | 1.23.1 | `pool/main/w/wayland/wayland-1.23.1.huddef` | 4 | 1 |
| `yajl` | 2.1.0 | `pool/main/y/yajl/yajl-2.1.0.huddef` | 3 | 2 |
| `zlib` | 1.3.1 | `pool/main/z/zlib/zlib-1.3.1.huddef` | 3 | 1 |

### Where each `.alt` came from


**`alsa-lib`** — canonical `pool/main/a/alsa-lib/alsa-lib-1.2.14.huddef` (`105b0cf02c1e`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `alsa-lib.huddef.alt1` | 1.2.14 | `d87aae0c873d` | `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/alsa-lib-1.2.14.huddef` |

**`bzip2`** — canonical `pool/main/b/bzip2/bzip2-1.0.8.huddef` (`68af70f95494`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `bzip2.huddef.alt1` | 1.0.8 | `076694bb8e88` | `sources/definitions/old/packages/bzip2-1.0.8.huddef` |

**`cmake`** — canonical `pool/main/c/cmake/cmake-4.1.0.huddef` (`84bd9c6847ba`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `cmake.huddef.alt1` | 3.31.0 | `9660504ee00c` | `sources/definitions/old/packages/cmake-3.31.0.huddef` |
| `cmake.huddef.alt2` | 4.1.0 | `bc510fc7d811` | `sources/definitions/old/packages/cmake-4.1.0.huddef` |

**`cups`** — canonical `pool/main/c/cups/cups-2.4.12.huddef` (`b3c87ab23ce9`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `cups.huddef.alt1` | 2.4.12 | `54ad470645bd` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/cups-2.4.12.huddef` |

**`curl`** — canonical `pool/main/c/curl/curl-8.15.0.huddef` (`c136a1aef1f5`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `curl.huddef.alt1` | 8.15.0 | `d8f3ff02b82b` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/curl-8.15.0.huddef` |
| `curl.huddef.alt2` | 8.6.0 | `cdc99a8f0121` | `sources/definitions/old/packages/curl-8.6.0.huddef` |

**`cyrus-sasl`** — canonical `pool/main/c/cyrus-sasl/cyrus-sasl-2.1.28.huddef` (`c32ac7e0e67a`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `cyrus-sasl.huddef.alt1` | 2.1.28 | `3f962a529571` | `sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/cyrus-sasl-2.1.28.huddef` |

**`dbus`** — canonical `pool/main/d/dbus/dbus-1.16.2.huddef` (`bcb986fff6cb`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `dbus.huddef.alt1` | 1.16.2 | `d43dfc8946f7` | `sources/definitions/old/1 Feb 2026/dbus-1.16.2.huddef` |
| `dbus.huddef.alt2` | 1.16.0 | `54db57dfc35c` | `sources/definitions/old/packages/dbus-1.16.0.huddef` |
| `dbus.huddef.alt3` | 1.16.2 | `91694f452095` | `sources/definitions/old/packages/dbus-1.16.2.huddef` |

**`dtc`** — canonical `pool/main/d/dtc/dtc-1.7.2.huddef` (`cdb6902b18be`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `dtc.huddef.alt1` | 1.7.2 | `b69bdfafe0e8` | `sources/definitions/old/packages/dtc-1.7.2.huddef` |
| `dtc.huddef.alt2` | 1.7.2 | `501266929615` | `sources/definitions/old/updated-packages/dtc-1.7.2.huddef` |

**`duktape`** — canonical `pool/main/d/duktape/duktape-2.7.0.huddef` (`66db8d7b1743`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `duktape.huddef.alt1` | 2.7.0 | `a48c0f459835` | `sources/definitions/old/1 Feb 2026/duktape-2.7.0.huddef` |

**`expat`** — canonical `pool/main/e/expat/expat-2.7.1.huddef` (`be710bd30b5c`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `expat.huddef.alt1` | 2.6.4 | `653abe89c93b` | `pool/main/e/expat/expat-2.6.4.huddef` |

**`firewalld`** — canonical `pool/main/f/firewalld/firewalld-2.3.2.huddef` (`d15f7fd90edc`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `firewalld.huddef.alt1` | 2.3.2 | `e6a0ad6168ce` | `sources/definitions/libvirt/firewalld-2.3.2.huddef` |

**`fontconfig`** — canonical `pool/main/f/fontconfig/fontconfig-2.17.1.huddef` (`cc30cb6c20a7`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `fontconfig.huddef.alt1` | 2.17.1 | `39d43cde0a9d` | `sources/definitions/old/0/fontconfig-2.17.1.huddef` |

**`freetype`** — canonical `pool/main/f/freetype/freetype-2.14.0.huddef` (`1e818d3c7bae`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `freetype.huddef.alt1` | 2.13.3 | `aaf004f1ae2d` | `sources/definitions/old/0/freetype-2.13.3.huddef` |

**`fribidi`** — canonical `pool/main/f/fribidi/fribidi-1.0.16.huddef` (`deb743a4241a`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `fribidi.huddef.alt1` | 1.0.16 | `24f6e9434551` | `sources/definitions/old/packages/fribidi-1.0.16.huddef` |

**`giflib`** — canonical `pool/main/g/giflib/giflib-5.2.2.huddef` (`c44b87eb7087`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `giflib.huddef.alt1` | 5.2.2 | `95f429da6784` | `sources/definitions/old/packages/giflib-5.2.2.huddef` |

**`glib`** — canonical `pool/main/g/glib/glib-2.84.4.huddef` (`4e3205bb940a`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `glib.huddef.alt1` | 2.84.4 | `4255bb4a8cb7` | `sources/definitions/glib/glib-2.84.4-stage1.huddef` |
| `glib.huddef.alt2` | 2.84.4 | `4328e961b32c` | `sources/definitions/glib/glib-2.84.4-stage2.huddef` |

**`glusterfs`** — canonical `pool/main/g/glusterfs/glusterfs-11.1.huddef` (`a2ce9d35dcf0`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `glusterfs.huddef.alt1` | 11.1 | `ccbaa9040ade` | `sources/definitions/old/packages/glusterfs-11.1.huddef` |

**`gnutls`** — canonical `pool/main/g/gnutls/gnutls-3.8.10.huddef` (`eb657dd32ae8`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `gnutls.huddef.alt1` | 3.8.10 | `f872937cde88` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/gnutls-3.8.10.huddef` |
| `gnutls.huddef.alt2` | 3.8.10 | `46515e000a23` | `sources/definitions/old/packages/gnutls-3.8.10.huddef` |

**`harfbuzz`** — canonical `pool/main/h/harfbuzz/harfbuzz-11.4.1.huddef` (`d03327b6a761`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `harfbuzz.huddef.alt1` | 11.4.1 | `3d04034c215b` | `sources/definitions/old/0/harfbuzz-11.4.1.huddef` |
| `harfbuzz.huddef.alt2` | 11.4.1 | `f8a41fad0843` | `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/harfbuzz-11.4.1.huddef` |

**`icu`** — canonical `pool/main/i/icu/icu-77.1.huddef` (`c1f5fcf93dac`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `icu.huddef.alt1` | 77.1 | `bc85ffb40acc` | `sources/definitions/old/0/icu-77.1.huddef` |
| `icu.huddef.alt2` | 77.1 | `f55ed3554a25` | `sources/definitions/old/packages/icu-77.1.huddef` |

**`iptables`** — canonical `pool/main/i/iptables/iptables-1.8.11.huddef` (`ec61860a7f03`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `iptables.huddef.alt1` | 1.8.11 | `7c8170e34af1` | `sources/definitions/old/packages/iptables-1.8.11.huddef` |

**`json-c`** — canonical `pool/main/j/json-c/json-c-0.18.huddef` (`4e80a800a4ff`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `json-c.huddef.alt1` | 0.18 | `ff9a83f177e5` | `sources/definitions/old/0/json-c-0.18.huddef` |

**`json-glib`** — canonical `pool/main/j/json-glib/json-glib-1.10.6.huddef` (`c71cf453f7a1`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `json-glib.huddef.alt1` | 1.10.6 | `e9c7326c5fae` | `sources/definitions/old/packages/json-glib-1.10.6.huddef` |
| `json-glib.huddef.alt2` | 1.10.6 | `5115ea60c364` | `sources/definitions/old/updated-packages/json-glib-1.10.6.huddef` |

**`kmod`** — canonical `pool/main/k/kmod/kmod-34.huddef` (`948db20716b1`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `kmod.huddef.alt1` | 34.2 | `fe6a6bb78f9d` | `sources/definitions/old/updated-packages/kmod-34.2.huddef` |

**`libICE`** — canonical `pool/main/l/libICE/libICE-1.1.2.huddef` (`92bc75b32b3d`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libICE.huddef.alt1` | 1.1.2 | `d72fd6f9d3e1` | `sources/definitions/old/0/libICE-1.1.2.huddef` |

**`libSM`** — canonical `pool/main/l/libSM/libSM-1.2.6.huddef` (`e414b3535208`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libSM.huddef.alt1` | 1.2.6 | `f6f4927c7512` | `sources/definitions/old/0/libSM-1.2.6.huddef` |

**`libX11`** — canonical `pool/main/l/libX11/libX11-1.8.12.huddef` (`eecc8aa1f6c5`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libX11.huddef.alt1` | 1.8.12 | `4f826ab97a8b` | `sources/definitions/old/0/libX11-1.8.12.huddef` |

**`libXau`** — canonical `pool/main/l/libXau/libXau-1.0.12.huddef` (`cbc9a028e700`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXau.huddef.alt1` | 1.0.12 | `6e045797e674` | `sources/definitions/old/0/libXau-1.0.12.huddef` |

**`libXdmcp`** — canonical `pool/main/l/libXdmcp/libXdmcp-1.1.5.huddef` (`2db5154c85fa`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXdmcp.huddef.alt1` | 1.1.5 | `8849ab2becf5` | `sources/definitions/old/0/libXdmcp-1.1.5.huddef` |

**`libXext`** — canonical `pool/main/l/libXext/libXext-1.3.6.huddef` (`6630d33542e1`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXext.huddef.alt1` | 1.3.6 | `4d80a98fb16b` | `sources/definitions/old/0/libXext-1.3.6.huddef` |

**`libXfixes`** — canonical `pool/main/l/libXfixes/libXfixes-6.0.1.huddef` (`ca0edff606e0`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXfixes.huddef.alt1` | 6.0.1 | `dc507651a9f6` | `sources/definitions/old/0/libXfixes-6.0.1.huddef` |

**`libXi`** — canonical `pool/main/l/libXi/libXi-1.8.2.huddef` (`20dde16d6aa5`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXi.huddef.alt1` | 1.8.2 | `6b63f4eee3de` | `sources/definitions/old/0/libXi-1.8.2.huddef` |

**`libXrandr`** — canonical `pool/main/l/libXrandr/libXrandr-1.5.4.huddef` (`0afe9b9b3baf`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXrandr.huddef.alt1` | 1.5.4 | `bfb57c89eef2` | `sources/definitions/old/0/libXrandr-1.5.4.huddef` |

**`libXrender`** — canonical `pool/main/l/libXrender/libXrender-0.9.12.huddef` (`5c8e579bdf82`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXrender.huddef.alt1` | 0.9.12 | `1faac7459221` | `sources/definitions/old/0/libXrender-0.9.12.huddef` |

**`libXt`** — canonical `pool/main/l/libXt/libXt-1.3.1.huddef` (`da073f9db9af`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXt.huddef.alt1` | 1.3.1 | `8ec50cfcb3b3` | `sources/definitions/old/0/libXt-1.3.1.huddef` |

**`libXtst`** — canonical `pool/main/l/libXtst/libXtst-1.2.5.huddef` (`af36b5468639`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libXtst.huddef.alt1` | 1.2.5 | `0920bf49ddf1` | `sources/definitions/old/0/libXtst-1.2.5.huddef` |

**`libaio`** — canonical `pool/main/l/libaio/libaio-0.3.113.huddef` (`492e0f788e72`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libaio.huddef.alt1` | 0.3.113 | `229deefce9e3` | `sources/definitions/old/packages/libaio-0.3.113.huddef` |

**`libdrm`** — canonical `pool/main/l/libdrm/libdrm-2.4.124.huddef` (`71ea3e46a398`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libdrm.huddef.alt1` | 2.4.125 | `5d27e2eeb0bd` | `sources/definitions/old/packages/libdrm-2.4.125.huddef` |

**`libevent`** — canonical `pool/main/l/libevent/libevent-2.1.12.huddef` (`f86be0971601`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libevent.huddef.alt1` | 2.1.12 | `da69c108ce66` | `sources/definitions/old/packages/libevent-2.1.12.huddef` |

**`libffi`** — canonical `pool/main/l/libffi/libffi-3.4.8.huddef` (`5b0c5971e20b`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libffi.huddef.alt1` | 3.4.6 | `1dd030e0748a` | `pool/main/l/libffi/libffi-3.4.6.huddef` |

**`libgcrypt`** — canonical `pool/main/l/libgcrypt/libgcrypt-1.11.2.huddef` (`355bc172dc55`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libgcrypt.huddef.alt1` | 1.11.1 | `757c854f214d` | `pool/main/l/libgcrypt/libgcrypt-1.11.1.huddef` |

**`libgpg-error`** — canonical `pool/main/l/libgpg-error/libgpg-error-1.55.huddef` (`f872cd04cc36`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libgpg-error.huddef.alt1` | 1.51 | `72278a0ee282` | `pool/main/l/libgpg-error/libgpg-error-1.51.huddef` |

**`libgudev`** — canonical `pool/main/l/libgudev/libgudev-238.huddef` (`cfb54766ee5b`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libgudev.huddef.alt1` | 238 | `d3624218306a` | `sources/definitions/old/packages/libgudev-238.huddef` |

**`libidn2`** — canonical `pool/main/l/libidn2/libidn2-2.3.8.huddef` (`bbc458f965c9`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libidn2.huddef.alt1` | 2.3.8 | `a02a831d4082` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libidn2-2.3.8.huddef` |
| `libidn2.huddef.alt2` | 2.3.7 | `aa0308cffc0d` | `sources/definitions/old/packages/libidn2-2.3.7.huddef` |

**`libjpeg`** — canonical `pool/main/l/libjpeg/libjpeg-3.0.1.huddef` (`ad4a45808105`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libjpeg.huddef.alt1` | 3.0.1 | `21fb8d1db7df` | `sources/definitions/old/packages/libjpeg-3.0.1.huddef` |

**`libndp`** — canonical `pool/main/l/libndp/libndp-1.9.huddef` (`de3b77ae9fee`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libndp.huddef.alt1` | 1.9 | `c6b862e0c844` | `sources/definitions/old/packages/libndp-1.9.huddef` |
| `libndp.huddef.alt2` | 1.9 | `596dd4a3bbef` | `sources/definitions/old/updated-packages/libndp-1.9.huddef` |

**`libpng`** — canonical `pool/main/l/libpng/libpng-1.6.50.huddef` (`aee876cf3ac6`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libpng.huddef.alt1` | 1.6.50 | `68b42d7c0ee1` | `sources/definitions/old/0/libpng-1.6.50.huddef` |

**`libpsl`** — canonical `pool/main/l/libpsl/libpsl-0.21.5.huddef` (`70b770aeeda2`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libpsl.huddef.alt1` | 0.21.5 | `5cb693793734` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libpsl-0.21.5.huddef` |
| `libpsl.huddef.alt2` | 0.21.5 | `fe7277d4298d` | `sources/definitions/old/packages/libpsl-0.21.5.huddef` |

**`libslirp`** — canonical `pool/main/l/libslirp/libslirp-4.9.1.huddef` (`42d47627bb2a`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libslirp.huddef.alt1` | 4.9.1 | `da4f867b5375` | `sources/definitions/old/packages/libslirp-4.9.1.huddef` |
| `libslirp.huddef.alt2` | 4.9.1 | `db4ace84b04c` | `sources/definitions/old/updated-packages/libpsl-0.21.5.huddef` |
| `libslirp.huddef.alt3` | 4.9.1 | `240aa5bf8673` | `sources/definitions/old/updated-packages/libslirp-4.9.1.huddef` |

**`libsndfile`** — canonical `pool/main/l/libsndfile/libsndfile-1.2.2.huddef` (`3772fb27d4c7`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libsndfile.huddef.alt1` | 1.2.2 | `abb09db68149` | `sources/definitions/old/packages/libsndfile-1.2.2.huddef` |

**`libtasn1`** — canonical `pool/main/l/libtasn1/libtasn1-4.20.0.huddef` (`104ed7459ba0`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libtasn1.huddef.alt1` | 4.20.0 | `db9ee9381e65` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libtasn1-4.20.0.huddef` |
| `libtasn1.huddef.alt2` | 4.20.0 | `62fb2d35ac5d` | `sources/definitions/old/packages/libtasn1-4.20.0.huddef` |

**`libtiff`** — canonical `pool/main/l/libtiff/libtiff-4.7.0.huddef` (`c8e61844178a`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libtiff.huddef.alt1` | 4.7.0 | `b108d10ecdb3` | `sources/definitions/old/0/libtiff-4.7.0.huddef` |

**`libtirpc`** — canonical `pool/main/l/libtirpc/libtirpc-1.3.7.huddef` (`fdd69609951f`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libtirpc.huddef.alt1` | 1.3.6 | `7520976d39c1` | `sources/definitions/14 Feb 2026/libtirpc-1.3.6.huddef` |
| `libtirpc.huddef.alt2` | 1.3.6 | `c28c14459486` | `sources/definitions/libtirpc-1.3.6.huddef` |

**`libunistring`** — canonical `pool/main/l/libunistring/libunistring-1.3.huddef` (`0fb262688eb5`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libunistring.huddef.alt1` | 1.3 | `fc88db1a8b0c` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libunistring-1.3.huddef` |
| `libunistring.huddef.alt2` | 1.3 | `cedaf587290e` | `sources/definitions/old/packages/libunistring-1.3.huddef` |

**`libvirt`** — canonical `pool/main/l/libvirt/libvirt-10.10.0.huddef` (`c344aa7999a9`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libvirt.huddef.alt1` | 10.10.0 | `0d8521f6f6b6` | `sources/definitions/13 Feb 2026/libvirt-10.10.0.huddef` |
| `libvirt.huddef.alt2` | 10.10.0 | `2b521891536e` | `sources/definitions/libvirt/libvirt-10.10.0.huddef` |
| `libvirt.huddef.alt3` | 10.10.0 | `e76fdfcd419d` | `sources/definitions/old/packages/libvirt-10.10.0.huddef` |

**`libvorbis`** — canonical `pool/main/l/libvorbis/libvorbis-1.3.7.huddef` (`a9541f5029ea`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libvorbis.huddef.alt1` | 1.3.7 | `0031f502b89f` | `sources/definitions/old/packages/libvorbis-1.3.7.huddef` |

**`libxcb`** — canonical `pool/main/l/libxcb/libxcb-1.17.0.huddef` (`77ddbde98ad0`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libxcb.huddef.alt1` | 1.17.0 | `2da36c1f1818` | `sources/definitions/old/0/libxcb-1.17.0.huddef` |

**`libxml2`** — canonical `pool/main/l/libxml2/libxml2-2.14.5.huddef` (`ab93302acc36`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libxml2.huddef.alt1` | 2.14.5 | `610047664581` | `sources/definitions/old/0/libxml2-2.14.5.huddef` |
| `libxml2.huddef.alt2` | 2.14.5 | `886151f0e02b` | `sources/definitions/old/packages/libxml2-2.14.5.huddef` |

**`libxslt`** — canonical `pool/main/l/libxslt/libxslt-1.1.43.huddef` (`058f155bda4f`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `libxslt.huddef.alt1` | 1.1.43 | `708e8d58b4ab` | `sources/definitions/old/0/libxslt-1.1.43.huddef` |

**`linux-pam`** — canonical `pool/main/l/linux-pam/linux-pam-1.7.1.huddef` (`ac4c824afbf2`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `linux-pam.huddef.alt1` | 1.7.1 | `442f3c23a7fb` | `sources/definitions/old/1 Feb 2026/linux-pam-1.7.1.huddef` |
| `linux-pam.huddef.alt2` | 1.7.0 | `4c139757ff8a` | `sources/definitions/old/packages/linux-pam-1.7.0.huddef` |
| `linux-pam.huddef.alt3` | 1.7.1 | `bc16378bee3d` | `sources/definitions/old/packages/linux-pam-1.7.1.huddef` |

**`make-ca`** — canonical `pool/main/m/make-ca/make-ca-1.16.1.huddef` (`7c64de9019c2`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `make-ca.huddef.alt1` | 1.16.1 | `c824978bfde0` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/make-ca-1.16.1.huddef` |
| `make-ca.huddef.alt2` | 1.16.1 | `b83962d618cc` | `sources/definitions/old/packages/make-ca-1.16.1.huddef` |

**`meson`** — canonical `pool/main/m/meson/meson-1.8.3.huddef` (`38013df4e575`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `meson.huddef.alt1` | 1.8.3 | `3eb9ef328243` | `sources/definitions/old/0/meson-1.8.3.huddef` |
| `meson.huddef.alt2` | 1.6.1 | `22802f9d539c` | `sources/definitions/old/packages/meson-1.6.1.huddef` |

**`ncurses`** — canonical `pool/main/n/ncurses/ncurses-6.5.20250809.huddef` (`55729ecafb5b`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `ncurses.huddef.alt1` | 6.5 | `e39c35edef22` | `sources/definitions/old/packages/ncurses-6.5.huddef` |

**`nettle`** — canonical `pool/main/n/nettle/nettle-3.10.2.huddef` (`814292a408bd`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `nettle.huddef.alt1` | 3.10.2 | `feb2993370c9` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/nettle-3.10.2.huddef` |
| `nettle.huddef.alt2` | 3.10.2 | `41dc8bfc2e4a` | `sources/definitions/old/packages/nettle-3.10.2.huddef` |

**`networkmanager`** — canonical `pool/main/n/networkmanager/networkmanager-1.54.0.huddef` (`6f7f4bc0fd1f`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `networkmanager.huddef.alt1` | 1.54.0 | `2e4c3ccedb87` | `sources/definitions/networkmanager-1.54.0.huddef` |
| `networkmanager.huddef.alt2` | 1.54.0 | `b4e4a5ddb35c` | `sources/definitions/networkmanager-huddef-packages/networkmanager-1.54.0-introspection.huddef` |
| `networkmanager.huddef.alt3` | 1.54.0 | `bf49f09410ec` | `sources/definitions/old/packages/networkmanager-1.54.0.huddef` |

**`newt`** — canonical `pool/main/n/newt/newt-0.52.25.huddef` (`195cd16c0132`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `newt.huddef.alt1` | 0.52.25 | `182c1cc9410f` | `sources/definitions/old/packages/newt-0.52.25.huddef` |

**`nftables`** — canonical `pool/main/n/nftables/nftables-1.1.1.huddef` (`1a7d7a72a6ff`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `nftables.huddef.alt1` | 1.1.1 | `8d4774bb0bf0` | `sources/definitions/13 Feb 2026/nftables-1.1.1.huddef` |
| `nftables.huddef.alt2` | 1.1.1 | `23255a31f464` | `sources/definitions/libvirt/nftables-1.1.1.huddef` |

**`nghttp2`** — canonical `pool/main/n/nghttp2/nghttp2-1.66.0.huddef` (`aaffdaa00caa`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `nghttp2.huddef.alt1` | 1.64.0 | `02a9337ab943` | `sources/definitions/old/packages/nghttp2-1.64.0.huddef` |

**`ninja`** — canonical `pool/main/n/ninja/ninja-1.13.1.huddef` (`75d51587acbc`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `ninja.huddef.alt1` | 1.13.1 | `874910c26575` | `sources/definitions/old/0/ninja-1.13.1.huddef` |
| `ninja.huddef.alt2` | 1.12.1 | `8c23d292da40` | `sources/definitions/old/packages/ninja-1.12.1.huddef` |

**`nspr`** — canonical `pool/main/n/nspr/nspr-4.37.huddef` (`4fada8196e10`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `nspr.huddef.alt1` | 4.36 | `7c84f51e8b28` | `sources/definitions/old/packages/nspr-4.36.huddef` |
| `nspr.huddef.alt2` | 4.37 | `0eb44b3435e4` | `sources/definitions/old/packages/nspr-4.37.huddef` |

**`openjdk`** — canonical `pool/main/o/openjdk/openjdk-24.0.2.huddef` (`ae1018ed38a4`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `openjdk.huddef.alt1` | 24.0.2 | `67954d2240c6` | `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/openjdk-24.0.2.huddef` |

**`openldap`** — canonical `pool/main/o/openldap/openldap-2.6.10.huddef` (`27c161fcb4cf`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `openldap.huddef.alt1` | 2.6.10 | `e18eed876c1b` | `sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/openldap-2.6.10.huddef` |

**`openssl`** — canonical `pool/main/o/openssl/openssl-3.5.2.huddef` (`94fe4ea9a70a`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `openssl.huddef.alt1` | 3.4.0 | `6db0a13b2d4e` | `sources/definitions/old/packages/openssl-3.4.0.huddef` |

**`p11-kit`** — canonical `pool/main/p/p11-kit/p11-kit-0.25.5.huddef` (`20db8acb3a46`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `p11-kit.huddef.alt1` | 0.25.5 | `55b7cc24b1d9` | `sources/definitions/old/1 Feb 2026/cups-huddef-packages/p11-kit-0.25.5.huddef` |
| `p11-kit.huddef.alt2` | 0.25.5 | `538a17b34c92` | `sources/definitions/old/packages/p11-kit-0.25.5.huddef` |

**`pcre2`** — canonical `pool/main/p/pcre2/pcre2-10.45.huddef` (`acd80c00ddc6`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `pcre2.huddef.alt1` | 10.45 | `68242473c1b3` | `sources/definitions/old/0/pcre2-10.45.huddef` |
| `pcre2.huddef.alt2` | 10.45 | `380254002729` | `sources/definitions/old/packages/pcre2-10.45.huddef` |

**`perl`** — canonical `pool/main/p/perl/perl-5.42.0.huddef` (`51261ae53978`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `perl.huddef.alt1` | 5.40.0 | `2b80cd0a412a` | `sources/definitions/old/packages/perl-5.40.0.huddef` |

**`pixman`** — canonical `pool/main/p/pixman/pixman-0.46.4.huddef` (`a7127d0178d5`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `pixman.huddef.alt1` | 0.44.2 | `ae6b28bbcdad` | `pool/main/p/pixman/pixman-0.44.2.huddef` |
| `pixman.huddef.alt2` | 0.46.4 | `e2eccd651dd3` | `sources/definitions/old/packages/pixman-0.46.4.huddef` |

**`polkit`** — canonical `pool/main/p/polkit/polkit-126.huddef` (`7ea4046c08ea`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `polkit.huddef.alt1` | 126 | `5588543cde6b` | `sources/definitions/old/1 Feb 2026/polkit-126.huddef` |
| `polkit.huddef.alt2` | 125 | `ba6a593cceeb` | `sources/definitions/old/packages/polkit-125.huddef` |

**`popt`** — canonical `pool/main/p/popt/popt-1.19.huddef` (`b7dc51ee4d61`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `popt.huddef.alt1` | 1.19 | `abffb52c132c` | `sources/definitions/old/packages/popt-1.19.huddef` |

**`postgresql`** — canonical `pool/main/p/postgresql/postgresql-17.6.huddef` (`8f5183721bcd`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `postgresql.huddef.alt1` | 17.6 | `6c2d07fc9da1` | `sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/postgresql-17.6.huddef` |

**`python-setuptools`** — canonical `pool/main/p/python-setuptools/python-setuptools-80.9.0.huddef` (`9fc7acb721e6`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `python-setuptools.huddef.alt1` | 78.1.0 | `98eaa813a0e6` | `sources/definitions/old/updated-packages/python-setuptools-78.1.0.huddef` |

**`python3`** — canonical `pool/main/p/python3/python3-3.13.7.huddef` (`b7541b2d5d6d`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `python3.huddef.alt1` | 3.13.7 | `0e4920a468eb` | `sources/definitions/old/packages/python3-3.13.7.huddef` |

**`qemu`** — canonical `pool/main/q/qemu/qemu-10.0.3.huddef` (`7460dd0acd12`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `qemu.huddef.alt1` | 10.0.3 | `4ee32460275d` | `sources/definitions/old/packages/qemu-10.0.3.huddef` |
| `qemu.huddef.alt2` | 10.0.3 | `b55e95dac6dc` | `sources/definitions/qemu-huddef/qemu-10.0.3.huddef` |

**`readline`** — canonical `pool/main/r/readline/readline-8.3.huddef` (`6120cde357b2`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `readline.huddef.alt1` | 8.2.13 | `c57634b5e938` | `sources/definitions/old/packages/readline-8.2.13.huddef` |

**`sanlock`** — canonical `pool/main/s/sanlock/sanlock-3.9.5.huddef` (`ea280c20d999`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `sanlock.huddef.alt1` | 3.9.4 | `54c5fd015f01` | `sources/definitions/old/packages/sanlock-3.9.4.huddef` |

**`sdl2`** — canonical `pool/main/s/sdl2/sdl2-2.32.8.huddef` (`44fc2abfcbeb`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `sdl2.huddef.alt1` | 2.32.8 | `35f09f1f1351` | `sources/definitions/old/packages/sdl2-2.32.8.huddef` |

**`slang`** — canonical `pool/main/s/slang/slang-2.3.3.huddef` (`08f95b8ac890`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `slang.huddef.alt1` | 2.3.3 | `b7706d595dfa` | `sources/definitions/old/packages/slang-2.3.3.huddef` |

**`sqlite`** — canonical `pool/main/s/sqlite/sqlite-3.50.4.huddef` (`07b7d31e94ad`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `sqlite.huddef.alt1` | 3.48.0 | `49bd20b2aa1e` | `sources/definitions/old/packages/sqlite-3.48.0.huddef` |

**`sudo`** — canonical `pool/main/s/sudo/sudo-1.9.17p2.huddef` (`77113988b530`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `sudo.huddef.alt1` | 1.9.16p2 | `18662dd27fe3` | `pool/main/s/sudo/sudo-1.9.16p2.huddef` |
| `sudo.huddef.alt2` | 1.9.17p2 | `70ea1c0173b2` | `sources/definitions/old/packages/sudo-1.9.17p2.huddef` |

**`systemd`** — canonical `pool/main/s/systemd/systemd-257.8.huddef` (`01d8aa660f6d`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `systemd.huddef.alt1` | 257.8 | `177c4f148727` | `sources/definitions/old/updated-packages/systemd-257.8.huddef` |

**`tree`** — canonical `pool/main/t/tree/tree-2.2.1.huddef` (`1e86de24b0ee`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `tree.huddef.alt1` | 2.2.1 | `b3bed259b8fe` | `sources/definitions/old/packages/tree-2.2.1.huddef` |

**`util-macros`** — canonical `pool/main/u/util-macros/util-macros-1.20.2.huddef` (`14dc1899c014`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `util-macros.huddef.alt1` | 1.20.2 | `479c6e0d0dfc` | `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/util-macros-1.20.2.huddef` |

**`vala`** — canonical `pool/main/v/vala/vala-0.56.18.huddef` (`5ad11fc0cb22`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `vala.huddef.alt1` | 0.56.18 | `5fee164ce122` | `sources/definitions/old/packages/vala-0.56.18.huddef` |

**`wayland`** — canonical `pool/main/w/wayland/wayland-1.23.1.huddef` (`bfd52c47b30d`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `wayland.huddef.alt1` | 1.24.0 | `c3a7c656b389` | `sources/definitions/old/packages/wayland-1.24.0.huddef` |

**`yajl`** — canonical `pool/main/y/yajl/yajl-2.1.0.huddef` (`cace9435f234`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `yajl.huddef.alt1` | 2.1.0 | `11c6052a172a` | `sources/definitions/old/0/yajl-2.1.0.huddef` |
| `yajl.huddef.alt2` | 2.1.0 | `173400ca353e` | `sources/definitions/old/packages/yajl-2.1.0.huddef` |

**`zlib`** — canonical `pool/main/z/zlib/zlib-1.3.1.huddef` (`4d0e1cd24351`)

| File | Version | sha256 | Origin |
|---|---|---|---|
| `zlib.huddef.alt1` | 1.3.1 | `a86e270132c7` | `sources/definitions/old/packages/zlib-1.3.1.huddef` |

---

## Packages taken without a tiebreak (149)

Every copy on disk agreed with the pool archive, so there was nothing to choose between.

| Package | Version | Copies in `sources/definitions/` |
|---|---|---|
| `acl` | 2.3.2 | 2 |
| `aom` | 3.12.1 | 1 |
| `attr` | 2.5.2 | 2 |
| `binutils` | 2.45 | 1 |
| `brotli` | 1.1.0 | 2 |
| `cpio` | 2.15 | 1 |
| `cracklib` | 2.10.3 | 2 |
| `dav1d` | 1.5.1 | 1 |
| `dbus-python` | 1.3.2 | 1 |
| `dejavu-fonts` | 2.37 | 2 |
| `dhcpcd` | 10.2.4 | 1 |
| `dmidecode` | 3.6 | 2 |
| `dnsmasq` | 2.91 | 2 |
| `docbook` | 4.5 | 1 |
| `docbook-xsl` | 1.79.2 | 1 |
| `flac` | 1.5.0 | 2 |
| `font-alias` | 1.0.5 | 2 |
| `font-util` | 1.4.1 | 2 |
| `gdb` | 16.3 | 2 |
| `git` | 2.50.1 | 2 |
| `gmp` | 6.3.0 | 1 |
| `gobject-introspection` | 1.84.0 | 1 |
| `gperf` | 3.1 | 1 |
| `gperftools` | 2.16 | 1 |
| `graphene` | 1.10.8 | 2 |
| `gstreamer` | 1.26.2 | 1 |
| `jansson` | 2.14 | 2 |
| `java-bin` | 24.0.2 | 1 |
| `lame` | 3.100 | 1 |
| `lcms2` | 2.17 | 1 |
| `libarchive` | 3.8.1 | 1 |
| `libcap` | 2.73 | 2 |
| `libedit` | 20240808 | 1 |
| `liberation-fonts` | 2.1.5 | 2 |
| `libev` | 4.33 | 2 |
| `libibverbs` | 53.0 | 2 |
| `libjpeg-turbo` | 3.1.1 | 2 |
| `libmnl` | 1.0.5 | 2 |
| `libnftnl` | 1.2.8 | 2 |
| `libnl` | 3.11.0 | 2 |
| `libogg` | 1.3.6 | 2 |
| `libpciaccess` | 0.18.1 | 2 |
| `libseat` | 0.9.1 | 2 |
| `libseccomp` | 2.6.0 | 1 |
| `libssh2` | 1.11.1 | 2 |
| `liburcu` | 0.14.1 | 1 |
| `libusb` | 1.0.28 | 1 |
| `libvpx` | 1.15.0 | 1 |
| `libwebp` | 1.6.0 | 2 |
| `libyaml` | 0.2.5 | 2 |
| `libzip` | 1.11.3 | 1 |
| `lmdb` | 0.9.33 | 1 |
| `mpc` | 1.3.1 | 1 |
| `mpfr` | 4.2.2 | 1 |
| `mtdev` | 1.1.7 | 2 |
| `nasm` | 2.16.03 | 1 |
| `nodejs` | 22.18.0 | 2 |
| `numactl` | 2.0.19 | 1 |
| `oniguruma` | 6.9.10 | 1 |
| `opus` | 1.5.2 | 2 |
| `postgresql-ha` | 17.6 | 2 |
| `postgresql-ldap` | 17.6 | 1 |
| `postgresql-ldap-ha` | 17.6 | 2 |
| `pygobject` | 3.50.0 | 1 |
| `python3-alabaster` | 1.0.0 | 1 |
| `python3-asciidoc` | 10.2.1 | 1 |
| `python3-attrs` | 25.3.0 | 1 |
| `python3-babel` | 2.17.0 | 1 |
| `python3-build` | 1.3.0 | 1 |
| `python3-cachecontrol` | 0.14.3 | 1 |
| `python3-certifi` | 2025.8.3 | 1 |
| `python3-chardet` | 5.2.0 | 1 |
| `python3-charset-normalizer` | 3.4.3 | 1 |
| `python3-commonmark` | 0.9.1 | 1 |
| `python3-cssselect` | 1.3.0 | 1 |
| `python3-cython` | 3.1.3 | 1 |
| `python3-distlib` | 0.3.9 | 1 |
| `python3-docutils` | 0.21.2 | 1 |
| `python3-doxypypy` | 0.8.8.7 | 1 |
| `python3-doxyqml` | 0.5.3 | 1 |
| `python3-editables` | 0.5 | 1 |
| `python3-gi-docgen` | 2025.4 | 1 |
| `python3-hatch-fancy-pypi-readme` | 25.1.0 | 1 |
| `python3-hatch-vcs` | 0.5.0 | 1 |
| `python3-hatchling` | 1.27.0 | 1 |
| `python3-html5lib` | 1.1 | 1 |
| `python3-idna` | 3.10 | 1 |
| `python3-imagesize` | 1.4.1 | 1 |
| `python3-iniconfig` | 2.1.0 | 1 |
| `python3-lxml` | 6.0.0 | 1 |
| `python3-mako` | 1.3.10 | 1 |
| `python3-markdown` | 3.8.2 | 1 |
| `python3-meson-python` | 0.18.0 | 1 |
| `python3-msgpack` | 1.1.1 | 1 |
| `python3-numpy` | 2.3.2 | 1 |
| `python3-pathspec` | 0.12.1 | 1 |
| `python3-pluggy` | 1.6.0 | 1 |
| `python3-ply` | 3.11 | 1 |
| `python3-psutil` | 7.0.0 | 1 |
| `python3-py3c` | 1.4 | 1 |
| `python3-pygdbmi` | 0.11.0.0 | 1 |
| `python3-pygments` | 2.19.2 | 1 |
| `python3-pyparsing` | 3.2.3 | 1 |
| `python3-pyproject-hooks` | 1.2.0 | 1 |
| `python3-pyproject-metadata` | 0.9.1 | 1 |
| `python3-pyserial` | 3.5 | 1 |
| `python3-pytest` | 8.4.1 | 1 |
| `python3-pytz` | 2025.2 | 1 |
| `python3-pyxdg` | 0.28 | 1 |
| `python3-pyyaml` | 6.0.2 | 1 |
| `python3-recommonmark` | 0.7.1 | 1 |
| `python3-requests` | 2.32.5 | 1 |
| `python3-roman-numerals-py` | 3.1.0 | 1 |
| `python3-scour` | 0.38.2 | 1 |
| `python3-sentry-sdk` | 2.35.0 | 1 |
| `python3-setuptools-scm` | 8.3.1 | 1 |
| `python3-six` | 1.17.0 | 1 |
| `python3-smartypants` | 2.0.2 | 1 |
| `python3-snowballstemmer` | 3.0.1 | 1 |
| `python3-sphinx` | 8.2.3 | 1 |
| `python3-sphinx-rtd-theme` | 3.0.2 | 1 |
| `python3-sphinxcontrib-applehelp` | 2.0.0 | 1 |
| `python3-sphinxcontrib-devhelp` | 2.0.0 | 1 |
| `python3-sphinxcontrib-htmlhelp` | 2.1.0 | 1 |
| `python3-sphinxcontrib-jquery` | 4.1 | 1 |
| `python3-sphinxcontrib-jsmath` | 1.0.1 | 1 |
| `python3-sphinxcontrib-qthelp` | 2.0.0 | 1 |
| `python3-sphinxcontrib-serializinghtml` | 2.0.0 | 1 |
| `python3-trove-classifiers` | 2025.8.6.13 | 1 |
| `python3-typogrify` | 2.1.0 | 1 |
| `python3-urllib3` | 2.5.0 | 1 |
| `python3-webencodings` | 0.5.1 | 1 |
| `rdma-core` | 53.0 | 2 |
| `util-linux` | 2.41.1 | 1 |
| `valgrind` | 3.25.1 | 2 |
| `vim` | 9.1.0 | 2 |
| `which` | 2.23 | 1 |
| `wpa_supplicant` | 2.11 | 1 |
| `x264` | 0.164 | 1 |
| `xbitmaps` | 1.1.3 | 2 |
| `xcb-proto` | 1.17.0 | 2 |
| `xkeyboard-config` | 2.44 | 2 |
| `xmlto` | 0.0.29 | 1 |
| `xorgproto` | 2024.1 | 2 |
| `xtrans` | 1.6.0 | 2 |
| `xz` | 5.8.0 | 2 |
| `yasm` | 1.3.0 | 1 |
| `zip` | 3.0 | 1 |
| `zstd` | 1.5.7 | 1 |
