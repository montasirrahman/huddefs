# Conversion progress — EASY packages

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


## Batch 1

0/3 built, average build 0s, cumulative elapsed 0.1h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `acl` | FAIL — [✗] Package not found: auto | — | 125 | — | — | — |
| `aom` | FAIL — [✗] Package not found: auto | — | 136 | — | — | — |
| `attr` | FAIL — [✗] Package not found: auto | — | 141 | — | — | — |

## Batch 1

1/4 built, average build 570s, cumulative elapsed 9.3h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `cracklib` | OK | OK | 570 | `_cracklib.so`, `libcrack.so.2` | `exec(sh)`, `libc.so.6`, `libz.so.1` | — |
| `cups` | FAIL — [✗] build dependency install failed | — | 176 | — | — | — |
| `curl` | FAIL — [✗] build dependency install failed | — | 194 | — | — | — |
| `dav1d` | FAIL — [✗] build dependency install failed | — | 209 | — | — | — |

## Batch 1

18/20 built, average build 232s, cumulative elapsed 11.7h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `cups` | OK — [✗] smoke | FAIL | 363 | `libcups.so.2`, `libcupsimage.so.2`, `pkgconfig(cups)` | `exec(sh)`, `libacl.so.1`, `libc.so.6`, `libcrypt.so.2`, `libdbus-1.so.3`, `libgcc_s.so.1`, `libgnutls.so.30`, `libm.so.6`, `libstdc++.so.6`, `libsystemd.so.0`, `libusb-1.0.so.0`, `libz.so.1`, `pkgconfig(gnutls)` | — |
| `curl` | OK — [✗] smoke | FAIL | 375 | `libcurl.so.4`, `pkgconfig(libcurl)` | `exec(sh)`, `libbrotlidec.so.1`, `libc.so.6`, `libcrypto.so.3`, `libidn2.so.0`, `libnghttp2.so.14`, `libpsl.so.5`, `libssh2.so.1`, `libssl.so.3`, `libz.so.1`, `libzstd.so.1`, `pkgconfig(libbrotlicommon)`, `pkgconfig(libbrotlidec)`, `pkgconfig(libidn2)`, `pkgconfig(libnghttp2)`, `pkgconfig(libpsl)`, `pkgconfig(libssh2)`, `pkgconfig(libzstd)`, `pkgconfig(openssl)`, `pkgconfig(zlib)` | — |
| `dav1d` | OK | OK | 333 | `libdav1d.so.7`, `pkgconfig(dav1d)` | `libc.so.6` | — |
| `dbus` | OK | OK | 164 | `libdbus-1.so.3`, `pkgconfig(dbus-1)` | `exec(python)`, `libc.so.6`, `libexpat.so.1`, `libsystemd.so.0`, `pkgconfig(libsystemd)` | — |
| `dbus-python` | OK — [✗] dbus-python failed | FAIL | 230 | `pkgconfig(dbus-python)` | `libc.so.6`, `libdbus-1.so.3`, `libglib-2.0.so.0`, `pkgconfig(dbus-1)` | — |
| `dejavu-fonts` | OK | OK | 178 | — | — | — |
| `dmidecode` | OK | OK | 165 | — | `libc.so.6` | — |
| `dtc` | OK | OK | 226 | `libfdt.so.1`, `pkgconfig(libfdt)` | `exec(bash)`, `libc.so.6` | — |
| `duktape` | OK | OK | 187 | `libduktape.so.207`, `libduktaped.so.207`, `pkgconfig(duktape)` | `libc.so.6` | — |
| `expat` | OK | OK | 170 | `libexpat.so.1`, `pkgconfig(expat)` | `libc.so.6`, `libm.so.6` | — |
| `flac` | OK | OK | 230 | `libFLAC++.so.11`, `libFLAC.so.14`, `pkgconfig(flac)`, `pkgconfig(flac++)` | `libc.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libstdc++.so.6` | — |
| `font-alias` | OK | OK | 187 | — | — | — |
| `font-util` | OK | OK | 197 | `pkgconfig(fontutil)` | `libc.so.6` | — |
| `fontconfig` | OK — dropped dependency removed functionality: lost exec(bash) | — | 260 | `libfontconfig.so.1`, `pkgconfig(fontconfig)` | `libbz2.so.1.0`, `libc.so.6`, `libexpat.so.1`, `libfreetype.so.6`, `libm.so.6`, `libpng16.so.16`, `libz.so.1`, `pkgconfig(expat)`, `pkgconfig(freetype2)` | — |
| `freetype` | OK — [✗] smoke | FAIL | 220 | `libfreetype.so.6`, `pkgconfig(freetype2)` | `exec(sh)`, `libbrotlidec.so.1`, `libbz2.so.1.0`, `libc.so.6`, `libm.so.6`, `libpng16.so.16`, `libz.so.1`, `pkgconfig(libbrotlidec)`, `pkgconfig(libpng)`, `pkgconfig(zlib)` | — |
| `fribidi` | OK | OK | 198 | `libfribidi.so.0`, `pkgconfig(fribidi)` | `libc.so.6` | — |
| `gdb` | FAIL — checking for library containing strerror... yes | — | 940 | — | — | — |
| `git` | FAIL —   libgpg-error N.N (NKiB) | — | 289 | — | — | — |
| `glib` | OK — [✗] smoke | FAIL | 290 | `libgio-2.0.so.0`, `libgirepository-2.0.so.0`, `libglib-2.0.so.0`, `libgmodule-2.0.so.0`, `libgobject-2.0.so.0`, `libgthread-2.0.so.0`, `pkgconfig(gio-2.0)`, `pkgconfig(gio-unix-2.0)`, `pkgconfig(girepository-2.0)`, `pkgconfig(glib-2.0)`, `pkgconfig(gmodule-2.0)`, `pkgconfig(gmodule-export-2.0)`, `pkgconfig(gmodule-no-export-2.0)`, `pkgconfig(gobject-2.0)`, `pkgconfig(gthread-2.0)` | `exec(python3)`, `exec(sh)`, `ld-linux-x86-64.so.2`, `libc.so.6`, `libelf.so.1`, `libffi.so.8`, `libm.so.6`, `libmount.so.1`, `libpcre2-8.so.0`, `libz.so.1`, `pkgconfig(libffi)`, `pkgconfig(libpcre2-8)`, `pkgconfig(mount)`, `pkgconfig(zlib)` | — |
| `gmp` | OK | OK | 199 | `libgmp.so.10`, `libgmpxx.so.4`, `pkgconfig(gmp)`, `pkgconfig(gmpxx)` | `libc.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libstdc++.so.6` | — |

## Batch 2

8/15 built, average build 313s, cumulative elapsed 13.1h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `gnutls` | OK — [✗] smoke | FAIL | 506 | `libgnutls.so.30`, `libgnutlsxx.so.30`, `pkgconfig(gnutls)` | `ld-linux-x86-64.so.2`, `libc.so.6`, `libgcc_s.so.1`, `libgmp.so.10`, `libhogweed.so.6`, `libidn2.so.0`, `libm.so.6`, `libnettle.so.8`, `libp11-kit.so.0`, `libstdc++.so.6`, `libtasn1.so.6`, `libunistring.so.5`, `pkgconfig(hogweed)`, `pkgconfig(libidn2)`, `pkgconfig(libtasn1)`, `pkgconfig(nettle)`, `pkgconfig(p11-kit-1)` | — |
| `gobject-introspection` | FAIL — Program rncNrng found: NO | — | 181 | — | — | — |
| `gperf` | OK | OK | 127 | — | `libc.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libstdc++.so.6` | — |
| `graphene` | FAIL — ModuleNotFoundError: No module named 'distutils' | — | 224 | — | — | — |
| `gstreamer` | FAIL — ModuleNotFoundError: No module named 'distutils' | — | 263 | — | — | — |
| `harfbuzz` | FAIL —   libgpg-error N.N (NKiB) | — | 225 | — | — | — |
| `icu` | OK | OK | 963 | `libicudata.so.77`, `libicui18n.so.77`, `libicuio.so.77`, `libicutest.so.77`, `libicutu.so.77`, `libicuuc.so.77`, `pkgconfig(icu-i18n)`, `pkgconfig(icu-io)`, `pkgconfig(icu-uc)` | `exec(sh)`, `ld-linux-x86-64.so.2`, `libc.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libstdc++.so.6` | — |
| `iptables` | OK | OK | 122 | `libip4tc.so.2`, `libip6tc.so.2`, `libipq.so.0`, `libxtables.so.12`, `pkgconfig(libip4tc)`, `pkgconfig(libip6tc)`, `pkgconfig(libipq)`, `pkgconfig(libiptc)`, `pkgconfig(xtables)` | `exec(bash)`, `libc.so.6`, `libm.so.6` | — |
| `jansson` | OK | OK | 139 | `libjansson.so.4`, `pkgconfig(jansson)` | `libc.so.6` | — |
| `json-c` | FAIL — [✗] build failed — see /var/hud-build/logs/json-c-N.N-NTNZ.log | — | 159 | — | — | — |
| `json-glib` | OK — [✗] smoke | FAIL | 232 | `libjson-glib-1.0.so.0`, `pkgconfig(json-glib-1.0)` | `libc.so.6`, `libgio-2.0.so.0`, `libglib-2.0.so.0`, `libgobject-2.0.so.0`, `pkgconfig(gio-2.0)` | — |
| `kmod` | OK | OK | 189 | `libkmod.so.2`, `pkgconfig(kmod)`, `pkgconfig(libkmod)` | `libc.so.6`, `libcrypto.so.3`, `liblzma.so.5`, `libz.so.1`, `libzstd.so.1`, `pkgconfig(libcrypto)`, `pkgconfig(liblzma)`, `pkgconfig(libzstd)`, `pkgconfig(zlib)` | — |
| `lame` | OK | OK | 223 | `libmp3lame.so.0` | `libc.so.6`, `libm.so.6`, `libncurses.so.6` | — |
| `lcms2` | FAIL — checking for jerror.h... yes | — | 220 | — | — | — |
| `libICE` | FAIL — [✗] build failed — see /var/hud-build/logs/libICE-N.N.N-NTNZ.log | — | 157 | — | — | — |

## Batch 1

14/20 built, average build 377s, cumulative elapsed 22.8h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `aom` | OK | OK | 498 | `libaom.so.3`, `pkgconfig(aom)` | `libc.so.6`, `libgcc_s.so.1`, `libm.so.6`, `libstdc++.so.6` | — |
| `attr` | OK | OK | 129 | `libattr.so.1`, `pkgconfig(libattr)` | `libc.so.6` | — |
| `cups` | OK | OK | 325 | `libcups.so.2`, `libcupsimage.so.2`, `pkgconfig(cups)` | `exec(sh)`, `libacl.so.1`, `libc.so.6`, `libcrypt.so.2`, `libdbus-1.so.3`, `libgcc_s.so.1`, `libgnutls.so.30`, `libm.so.6`, `libstdc++.so.6`, `libsystemd.so.0`, `libusb-1.0.so.0`, `libz.so.1`, `pkgconfig(gnutls)` | — |
| `curl` | OK | OK | 391 | `libcurl.so.4`, `pkgconfig(libcurl)` | `exec(sh)`, `libbrotlidec.so.1`, `libc.so.6`, `libcrypto.so.3`, `libidn2.so.0`, `libnghttp2.so.14`, `libpsl.so.5`, `libssh2.so.1`, `libssl.so.3`, `libz.so.1`, `libzstd.so.1`, `pkgconfig(libbrotlicommon)`, `pkgconfig(libbrotlidec)`, `pkgconfig(libidn2)`, `pkgconfig(libnghttp2)`, `pkgconfig(libpsl)`, `pkgconfig(libssh2)`, `pkgconfig(libzstd)`, `pkgconfig(openssl)`, `pkgconfig(zlib)` | — |
| `dav1d` | OK | OK | 311 | `libdav1d.so.7`, `pkgconfig(dav1d)` | `libc.so.6` | — |
| `dbus-python` | OK | OK | 235 | `pkgconfig(dbus-python)` | `libc.so.6`, `libdbus-1.so.3`, `libglib-2.0.so.0`, `pkgconfig(dbus-1)` | — |
| `freetype` | OK | OK | 224 | `libfreetype.so.6`, `pkgconfig(freetype2)` | `exec(sh)`, `libbrotlidec.so.1`, `libbz2.so.1.0`, `libc.so.6`, `libm.so.6`, `libpng16.so.16`, `libz.so.1`, `pkgconfig(libbrotlidec)`, `pkgconfig(libpng)`, `pkgconfig(zlib)` | — |
| `gdb` | FAIL — checking for library containing strerror... no | — | 993 | — | — | — |
| `git` | FAIL —   libgpg-error N.N (NKiB) | — | 331 | — | — | — |
| `glib` | OK | OK | 312 | `libgio-2.0.so.0`, `libgirepository-2.0.so.0`, `libglib-2.0.so.0`, `libgmodule-2.0.so.0`, `libgobject-2.0.so.0`, `libgthread-2.0.so.0`, `pkgconfig(gio-2.0)`, `pkgconfig(gio-unix-2.0)`, `pkgconfig(girepository-2.0)`, `pkgconfig(glib-2.0)`, `pkgconfig(gmodule-2.0)`, `pkgconfig(gmodule-export-2.0)`, `pkgconfig(gmodule-no-export-2.0)`, `pkgconfig(gobject-2.0)`, `pkgconfig(gthread-2.0)` | `exec(python3)`, `exec(sh)`, `ld-linux-x86-64.so.2`, `libc.so.6`, `libelf.so.1`, `libffi.so.8`, `libm.so.6`, `libmount.so.1`, `libpcre2-8.so.0`, `libz.so.1`, `pkgconfig(libffi)`, `pkgconfig(libpcre2-8)`, `pkgconfig(mount)`, `pkgconfig(zlib)` | — |
| `gnutls` | OK | OK | 455 | `libgnutls.so.30`, `libgnutlsxx.so.30`, `pkgconfig(gnutls)` | `ld-linux-x86-64.so.2`, `libc.so.6`, `libgcc_s.so.1`, `libgmp.so.10`, `libhogweed.so.6`, `libidn2.so.0`, `libm.so.6`, `libnettle.so.8`, `libp11-kit.so.0`, `libstdc++.so.6`, `libtasn1.so.6`, `libunistring.so.5`, `pkgconfig(hogweed)`, `pkgconfig(libidn2)`, `pkgconfig(libtasn1)`, `pkgconfig(nettle)`, `pkgconfig(p11-kit-1)` | — |
| `gobject-introspection` | OK — [✗] install | FAIL | 544 | `libgirepository-1.0.so.1`, `pkgconfig(gobject-introspection-1.0)`, `pkgconfig(gobject-introspection-no-export-1.0)` | `exec(python3)`, `libc.so.6`, `libffi.so.8`, `libgio-2.0.so.0`, `libglib-2.0.so.0`, `libgmodule-2.0.so.0`, `libgobject-2.0.so.0`, `libm.so.6`, `pkgconfig(glib-2.0)`, `pkgconfig(gobject-2.0)` | **`python-setuptools`** |
| `graphene` | OK | OK | 521 | `libgraphene-1.0.so.0`, `pkgconfig(graphene-1.0)`, `pkgconfig(graphene-gobject-1.0)` | `exec(python3)`, `libc.so.6`, `libglib-2.0.so.0`, `libgobject-2.0.so.0`, `libm.so.6`, `pkgconfig(gobject-2.0)` | **`python-setuptools`** |
| `gstreamer` | OK | OK | 644 | `libgstbase-1.0.so.0`, `libgstcheck-1.0.so.0`, `libgstcontroller-1.0.so.0`, `libgstcoreelements.so`, `libgstcoretracers.so`, `libgstnet-1.0.so.0`, `libgstreamer-1.0.so.0`, `pkgconfig(gstreamer-1.0)`, `pkgconfig(gstreamer-base-1.0)`, `pkgconfig(gstreamer-check-1.0)`, `pkgconfig(gstreamer-controller-1.0)`, `pkgconfig(gstreamer-net-1.0)` | `exec(python3)`, `libc.so.6`, `libgio-2.0.so.0`, `libglib-2.0.so.0`, `libgmodule-2.0.so.0`, `libgobject-2.0.so.0`, `libm.so.6`, `pkgconfig(gio-2.0)`, `pkgconfig(gio-unix-2.0)`, `pkgconfig(glib-2.0)`, `pkgconfig(gmodule-no-export-2.0)`, `pkgconfig(gobject-2.0)` | **`python-setuptools`** |
| `harfbuzz` | FAIL —   libgpg-error N.N (NKiB) | — | 283 | — | — | — |
| `json-c` | OK | OK | 435 | `libjson-c.so.5`, `pkgconfig(json-c)` | `ld-linux-x86-64.so.2`, `libc.so.6`, `libm.so.6` | **`cmake`** |
| `json-glib` | OK | OK | 260 | `libjson-glib-1.0.so.0`, `pkgconfig(json-glib-1.0)` | `libc.so.6`, `libgio-2.0.so.0`, `libglib-2.0.so.0`, `libgobject-2.0.so.0`, `pkgconfig(gio-2.0)` | — |
| `lcms2` | FAIL — checking for jerror.h... yes | — | 249 | — | — | — |
| `libICE` | FAIL — [✗] build failed — see /var/hud-build/logs/libICE-N.N.N-NTNZ.log | — | 186 | — | — | — |
| `libSM` | FAIL — [✗] build failed — see /var/hud-build/logs/libSM-N.N.N-NTNZ.log | — | 196 | — | — | — |

## Batch 2

0/7 built, average build 0s, cumulative elapsed 23.2h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `libX11` | FAIL — [✗] build failed — see /var/hud-build/logs/libXN-N.N.N-NTNZ.log | — | 214 | — | — | — |
| `libXau` | FAIL — [✗] build failed — see /var/hud-build/logs/libXau-N.N.N-NTNZ.log | — | 206 | — | — | — |
| `libXdmcp` | FAIL — [✗] build failed — see /var/hud-build/logs/libXdmcp-N.N.N-NTNZ.log | — | 193 | — | — | — |
| `libXext` | FAIL — [✗] build failed — see /var/hud-build/logs/libXext-N.N.N-NTNZ.log | — | 235 | — | — | — |
| `libXfixes` | FAIL — [✗] build failed — see /var/hud-build/logs/libXfixes-N.N.N-NTNZ.log | — | 221 | — | — | — |
| `libXi` | FAIL — [✗] build failed — see /var/hud-build/logs/libXi-N.N.N-NTNZ.log | — | 220 | — | — | — |
| `libXrandr` | FAIL — [✗] build failed — see /var/hud-build/logs/libXrandr-N.N.N-NTNZ.log | — | 227 | — | — | — |

## Batch 1

19/20 built, average build 205s, cumulative elapsed 25.3h

| Package | Build | Test | Build s | Provides | Requires | Undeclared Build-Depends |
|---|---|---|---|---|---|---|
| `libICE` | OK | OK | 186 | `libICE.so.6`, `pkgconfig(ice)` | `libc.so.6`, `pkgconfig(xproto)` | — |
| `libSM` | OK | OK | 205 | `libSM.so.6`, `pkgconfig(sm)` | `libICE.so.6`, `libc.so.6`, `libuuid.so.1`, `pkgconfig(ice)`, `pkgconfig(uuid)`, `pkgconfig(xproto)` | — |
| `libX11` | OK | OK | 292 | `libX11-xcb.so.1`, `libX11.so.6`, `pkgconfig(x11)`, `pkgconfig(x11-xcb)` | `libXau.so.6`, `libXdmcp.so.6`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(kbproto)`, `pkgconfig(xcb)`, `pkgconfig(xproto)` | — |
| `libXau` | OK | OK | 222 | `libXau.so.6`, `pkgconfig(xau)` | `libc.so.6`, `pkgconfig(xproto)` | — |
| `libXdmcp` | OK | OK | 221 | `libXdmcp.so.6`, `pkgconfig(xdmcp)` | `libc.so.6`, `pkgconfig(xproto)` | — |
| `libXext` | OK | OK | 223 | `libXext.so.6`, `pkgconfig(xext)` | `libX11.so.6`, `libXau.so.6`, `libXdmcp.so.6`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(x11)`, `pkgconfig(xextproto)` | — |
| `libXfixes` | OK | OK | 221 | `libXfixes.so.3`, `pkgconfig(xfixes)` | `libX11.so.6`, `libXau.so.6`, `libXdmcp.so.6`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(fixesproto)`, `pkgconfig(x11)`, `pkgconfig(xproto)` | — |
| `libXi` | OK | OK | 223 | `libXi.so.6`, `pkgconfig(xi)` | `libX11.so.6`, `libXau.so.6`, `libXdmcp.so.6`, `libXext.so.6`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(inputproto)`, `pkgconfig(x11)`, `pkgconfig(xext)`, `pkgconfig(xfixes)` | — |
| `libXrandr` | OK | OK | 219 | `libXrandr.so.2`, `pkgconfig(xrandr)` | `libX11.so.6`, `libXau.so.6`, `libXdmcp.so.6`, `libXext.so.6`, `libXrender.so.1`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(randrproto)`, `pkgconfig(x11)`, `pkgconfig(xext)`, `pkgconfig(xproto)`, `pkgconfig(xrender)` | — |
| `libXrender` | OK | OK | 162 | `libXrender.so.1`, `pkgconfig(xrender)` | `libX11.so.6`, `libXau.so.6`, `libXdmcp.so.6`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(renderproto)`, `pkgconfig(x11)`, `pkgconfig(xproto)` | — |
| `libXt` | FAIL — checking if gcc supports -Werror=unknown-warning-option... no | — | 232 | — | — | — |
| `libXtst` | OK | OK | 195 | `libXtst.so.6`, `pkgconfig(xtst)` | `libX11.so.6`, `libXau.so.6`, `libXdmcp.so.6`, `libXext.so.6`, `libXi.so.6`, `libc.so.6`, `libxcb.so.1`, `pkgconfig(recordproto)`, `pkgconfig(x11)`, `pkgconfig(xext)`, `pkgconfig(xextproto)`, `pkgconfig(xi)` | — |
| `libaio` | OK | OK | 151 | `libaio.so.1` | `libc.so.6` | — |
| `libarchive` | OK | OK | 257 | `libarchive.so.13`, `pkgconfig(libarchive)` | `libacl.so.1`, `libbz2.so.1.0`, `libc.so.6`, `libcrypto.so.3`, `libexpat.so.1`, `liblz4.so.1`, `liblzma.so.5`, `libz.so.1`, `libzstd.so.1`, `pkgconfig(libcrypto)` | — |
| `libcap` | OK | OK | 125 | `libcap.so.2`, `libpsx.so.2`, `pkgconfig(libcap)`, `pkgconfig(libpsx)` | `libc.so.6` | — |
| `libdrm` | OK | OK | 236 | `libdrm.so.2`, `libdrm_amdgpu.so.1`, `libdrm_intel.so.1`, `libdrm_nouveau.so.2`, `libdrm_radeon.so.1`, `pkgconfig(libdrm)`, `pkgconfig(libdrm_amdgpu)`, `pkgconfig(libdrm_intel)`, `pkgconfig(libdrm_nouveau)`, `pkgconfig(libdrm_radeon)` | `libc.so.6`, `libpciaccess.so.0`, `pkgconfig(pciaccess)` | — |
| `libedit` | OK | OK | 170 | `libedit.so.0`, `pkgconfig(libedit)` | `libc.so.6`, `libncursesw.so.6` | — |
| `liberation-fonts` | OK | OK | 178 | — | — | — |
| `libev` | OK | OK | 164 | `libev.so.4` | `libc.so.6`, `libm.so.6` | — |
| `libevent` | OK | OK | 240 | `libevent-2.1.so.7`, `libevent_core-2.1.so.7`, `libevent_extra-2.1.so.7`, `libevent_openssl-2.1.so.7`, `libevent_pthreads-2.1.so.7`, `pkgconfig(libevent)`, `pkgconfig(libevent_core)`, `pkgconfig(libevent_extra)`, `pkgconfig(libevent_openssl)`, `pkgconfig(libevent_pthreads)` | `exec(python3)`, `libc.so.6`, `libcrypto.so.3`, `libssl.so.3` | — |
