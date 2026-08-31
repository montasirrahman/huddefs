# Duplicate report — `.huddef` definitions

Generated 2026-08-31 on **bf-repo** (`hud-server-local`, 172.19.1.7).
This analysis was **read-only**: every file under `/var/www/hud-repo/` was hashed and
diffed in place, nothing was written, moved or deleted.

## Method

- Walked `/var/www/hud-repo/sources/definitions/` recursively for `*.huddef`.
- Recorded each file's path, **sha256** and **md5** (md5 is kept because the earlier
  audit and `docs/WORKFLOW.md` step 1 both use `md5sum`, so its figures are comparable).
- Grouped by the `Package:` header **inside** the file rather than by filename. All
  690 files carry a parseable `Package:` header, so no filename guessing was needed.
- Compared each group against the archived copy in
  `/var/www/hud-repo/pool/main/<letter>/<name>/`, which per `CLAUDE.md` is the
  definition that actually built the shipped `.hud`, and is therefore the tiebreaker.

## Summary counts

| Metric | Count |
|---|---|
| `.huddef` in `sources/definitions/` | **690** |
| `.huddef` archived in `pool/` | **251** |
| **Total `.huddef` on bf-repo** | **941** |
| Distinct contents (sha256) in definitions tree | 567 |
| Distinct filenames in definitions tree | 457 |
| Distinct filenames across both trees | 462 |
| Distinct package names in definitions tree | 421 |
| Package directories in `pool/main/` | 245 |
| Published `.hud` packages | **245** |

### Reconciliation against the earlier audit

The audit's headline figures are reproduced exactly, once two counting conventions
are made explicit.

| Audit figure | Found | Status |
|---|---|---|
| 941 total files | 690 + 251 = **941** | **matches** — the 941 counts the definitions tree *and* the pool archives. The definitions tree alone holds 690. |
| 462 unique filenames | **462** across both trees | **matches** (457 in the definitions tree alone) |
| 245 packages published | **245** | **matches** |
| `qemu-10.0.3.huddef`: 5 copies, 3 contents | **5** in definitions (6 with the pool copy), **3** contents | **matches** |
| hashes `579be1ff` ×2, `57deaa4f` ×2, `1d8bc7df` ×1 | md5 `579be1ff` ×2, `57deaa4f` ×2, `1d8bc7df` ×1 in definitions | **matches** — these are **md5**, not sha256 |

No discrepancy against the audit remains. Nothing appears to have been lost.

## Classification

| Category | Packages |
|---|---|
| Single copy — only one definition exists | 250 |
| **IDENTICAL** — 2+ copies, all byte-identical | **64** |
| **CONFLICTING** — 2+ genuinely different contents | **107** |
| **ORPHANED** — definition with no package in the pool | **176** |
| **MISSING** — pool package with no definition | **0** |
| Total distinct package names | 421 |

Two facts that make the consolidation in Phase C tractable:

1. **Of the 107 conflicting packages, 95 have a pool copy, and in every one of those
   the pool copy is byte-identical to one of the variants on disk.** The tiebreaker
   never has to invent a winner — it only has to pick one.
2. **MISSING is empty.** Every one of the 245 published packages has at least one
   definition in the tree. Nothing shipped is unreproducible for want of a definition.

The 12 conflicting packages with **no** pool entry have no tiebreaker and need your
judgement; they are listed in the appendix below.

Of the 107 conflicts, **85 are true conflicts** — two files declaring the *same*
`Version:` with different content — while **22 differ only because they carry different
`Version:` values**, which is ordinary version history rather than a conflict.

---

## Appendix: state of the 251 shipped definitions

Counted over `pool/main/**/*.huddef` — the definitions that actually built the
published packages. Read-only `grep`; included because it sizes the v2 conversion
in Phase E and confirms two items in `CLAUDE.md`.

| Pattern | Files | Note |
|---|---|---|
| `Source-SHA256:` present | **0 / 251** | every shipped definition is v1; no build is currently reproducible |
| `Build-Depends:` present | **0 / 251** | build and runtime deps are still merged into `Depends:` |
| `pip3 install` during build | **72 / 251** | network access mid-build, forbidden under v2. Overlaps the ~60 empty `python3-*` packages. |
| any `\|\| true` | 203 / 251 | mostly benign (`chgrp`, `ln -sf`, symlink workarounds); each needs an eye during conversion |
| `\|\| true` guarding a **patch** | **1 / 251** | `qemu` |
| `\|\| true` guarding a **download** | **1 / 251** | `qemu` |
| uses `wget` | 2 / 251 | and `wget` is not installed anywhere |

### The qemu breakage is confirmed, and it is contained

`CLAUDE.md` item 3 predicted the shipped qemu is unpatched. The archived definition
that built it, `pool/main/q/qemu/qemu-10.0.3.huddef`, contains exactly the predicted
sequence at lines 22–26:

```bash
pip3 install distlib --break-system-packages 2>/dev/null || pip3 install distlib
wget -nc https://www.linuxfromscratch.org/patches/blfs/12.4/qemu-10.0.3-python_fixes-1.patch \
     -O ../qemu-10.0.3-python_fixes-1.patch 2>/dev/null || true
patch -Np1 -i ../qemu-10.0.3-python_fixes-1.patch || true
```

With `wget` absent, the download fails, `2>/dev/null || true` swallows it, the patch
then has no file to apply, `|| true` swallows that too, and the build reports success.
**The shipped qemu is almost certainly unpatched.**

The containment is the good news: **only this one definition guards a patch or a
download with `|| true`.** The pattern did not spread. Fixing qemu fixes the class.

Note also that the two rejected qemu variants list a far larger `Depends:` line
(`gnutls,keyutils,libslirp,pipewire,…`) and set `Service: qemu`. The pool copy —
the one that shipped — carries the shorter `Depends: glib, pixman, alsa-lib, dtc,
libslirp, sdl2`. Phase C keeps the pool copy; the alternatives are preserved as
`.alt` files rather than discarded, because that longer dependency list may be
closer to correct.

## The 12 conflicting packages with no pool copy

No published package, so no tiebreaker exists. Consolidation cannot resolve these
automatically and they are flagged for your review:

- `cairo`
- `gdk-pixbuf`
- `glib2`
- `gtk3`
- `libepoxy`
- `libvirt-python`
- `mesa`
- `nss`
- `ovirt-engine`
- `pango`
- `python-requests`
- `vdsm`

---

# CONFLICTING — 107 packages

For each: every copy with its sha256, which one the pool copy matches, and a unified
diff from the pool copy to each differing variant.

Legend: **`= POOL`** the pool copy's content · `alt` a variant that differs from it.


## Same `Version:`, different content — 85 packages

These are real conflicts: two files claim to build the same version but do not agree.


### `alsa-lib`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/a/alsa-lib/alsa-lib-1.2.14.huddef` | 1.2.14 | `105b0cf02c1e` | `940a693e210a` | **POOL** |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/alsa-lib-1.2.14.huddef` | 1.2.14 | `d87aae0c873d` | `79c93d40568b` | alt |
| `sources/definitions/old/packages/alsa-lib-1.2.14.huddef` | 1.2.14 | `105b0cf02c1e` | `940a693e210a` | **= POOL** |
| `sources/definitions/old/updated-packages/alsa-lib-1.2.14.huddef` | 1.2.14 | `105b0cf02c1e` | `940a693e210a` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/alsa-lib-1.2.14.huddef</code> (18 added, 13 removed)</summary>

```diff
--- pool/main/a/alsa-lib/alsa-lib-1.2.14.huddef
+++ sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/alsa-lib-1.2.14.huddef
@@ -1,14 +1,20 @@
 # HUD Package Definition - alsa-lib 1.2.14
-# Auto-generated for oVirt infrastructure
+# ALSA Sound Library
+# Library for accessing ALSA sound interface
 
 Package: alsa-lib
 Version: 1.2.14
 Architecture: x86_64
-Section: libraries
-Depends: 
-Description: alsa-lib-1.2.14
+Section: multimedia
+Depends:
+Description: ALSA library used by programs requiring access to the ALSA sound interface
 Source: https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.14.tar.bz2
+ExtraSource: https://www.alsa-project.org/files/pub/lib/alsa-ucm-conf-1.2.14.tar.bz2
 
 [configure]
+# Fix for GCC-15: remove failing test
+sed 's/playmidi1//' -i test/Makefile.am 2>/dev/null || true
+autoreconf -fi 2>/dev/null || true
+
 ./configure --prefix=/opt/hud
 
@@ -17,14 +23,13 @@
 
 [install]
-make install &&
-tar -C /usr/share/alsa --strip-components=1 -xf ../alsa-ucm-conf-1.2.14.tar.bz2
+make DESTDIR=$DESTDIR install
+
+# Install UCM configuration files if extra source exists
+if [ -f ../alsa-ucm-conf-1.2.14.tar.bz2 ]; then
+    tar -C $DESTDIR/opt/hud/share/alsa --strip-components=1 -xf ../alsa-ucm-conf-1.2.14.tar.bz2
+fi
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "alsa-lib 1.2.14 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ alsa-lib 1.2.14 installed to /opt/hud"
+echo "  Note: Kernel ALSA support (CONFIG_SND) must be enabled"
```

</details>


### `bzip2`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/b/bzip2/bzip2-1.0.8.huddef` | 1.0.8 | `68af70f95494` | `53368c44adfd` | **POOL** |
| `sources/definitions/old/bzip2-1.0.8.huddef` | 1.0.8 | `68af70f95494` | `53368c44adfd` | **= POOL** |
| `sources/definitions/old/packages/bzip2-1.0.8.huddef` | 1.0.8 | `076694bb8e88` | `5e19edd03337` | alt |
| `sources/definitions/old/updated-packages/bzip2-1.0.8.huddef` | 1.0.8 | `68af70f95494` | `53368c44adfd` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/bzip2-1.0.8.huddef</code> (0 added, 1 removed)</summary>

```diff
--- pool/main/b/bzip2/bzip2-1.0.8.huddef
+++ sources/definitions/old/packages/bzip2-1.0.8.huddef
@@ -29,3 +29,2 @@
 ldconfig 2>/dev/null || true
 echo "✓ bzip2 1.0.8 installed to /opt/hud"
-
```

</details>


### `cairo`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/0/cairo-1.18.4.huddef` | 1.18.4 | `ef14db2afed4` | `b86ac71e5e3d` | alt |
| `sources/definitions/old/packages/cairo-1.18.4.huddef` | 1.18.4 | `60844cfb4eb5` | `a16e46309a49` | alt |
| `sources/definitions/old/updated-packages/cairo-1.18.4.huddef` | 1.18.4 | `60844cfb4eb5` | `a16e46309a49` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/0/cairo-1.18.4.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/cairo-1.18.4.huddef</code> (19 added, 12 removed)</summary>

```diff
--- sources/definitions/old/0/cairo-1.18.4.huddef
+++ sources/definitions/old/packages/cairo-1.18.4.huddef
@@ -1,22 +1,29 @@
 # HUD Package Definition - cairo 1.18.4
-# 2D graphics library
+# Auto-generated for oVirt infrastructure
+
 Package: cairo
 Version: 1.18.4
 Architecture: x86_64
 Section: graphics
-Depends: libpng,pixman,fontconfig,freetype,glib,libX11,libXext,libXrender
-Description: 2D graphics library with support for multiple output devices
+Depends: gs,glib2,poppler,fontconfig,librsvg,xorg7-lib,lzo,gtk-doc,libpng
+Description: Cairo-1.18.4
 Source: https://www.cairographics.org/releases/cairo-1.18.4.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release -Dtee=enabled -Dxcb=enabled -Dxlib=enabled ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ cairo 1.18.4 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "cairo 1.18.4 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `cmake`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/c/cmake/cmake-4.1.0.huddef` | 4.1.0 | `84bd9c6847ba` | `4f9093a64288` | **POOL** |
| `sources/definitions/old/packages/cmake-3.31.0.huddef` | 3.31.0 | `9660504ee00c` | `10a4b139b150` | alt |
| `sources/definitions/old/packages/cmake-4.1.0.huddef` | 4.1.0 | `bc510fc7d811` | `058e83edbf21` | alt |
| `sources/definitions/old/updated-packages/cmake-4.1.0.huddef` | 4.1.0 | `84bd9c6847ba` | `4f9093a64288` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/cmake-3.31.0.huddef</code> (15 added, 19 removed)</summary>

```diff
--- pool/main/c/cmake/cmake-4.1.0.huddef
+++ sources/definitions/old/packages/cmake-3.31.0.huddef
@@ -1,25 +1,21 @@
-# HUD Package Definition - CMake 4.1.0
-# Modern build system generator - Based on LFS 12.4
-# Note: Can be built with minimal deps using bundled libraries
+# HUD Package Definition - cmake 3.31.0
+# Cross-platform build system
 
 Package: cmake
-Version: 4.1.0
+Version: 3.31.0
 Architecture: x86_64
 Section: development
-Depends: curl, libarchive, libuv, nghttp2
-Description: CMake - Cross-platform build system generator
-Source: https://cmake.org/files/v4.1/cmake-4.1.0.tar.gz
+Depends: openssl,zlib,curl
+Description: Cross-platform build system generator
+Source: https://github.com/Kitware/CMake/releases/download/v3.31.0/cmake-3.31.0.tar.gz
 
 [configure]
-# Fix lib64 issue
-sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
-
-# Bootstrap cmake - use system libs where available, bundle the rest
-./bootstrap --prefix=/opt/hud \
-            --mandir=/opt/hud/share/man \
-            --no-system-jsoncpp \
-            --no-system-cppdap \
-            --no-system-librhash \
-            --parallel=$(nproc)
+./bootstrap \
+    --prefix=/opt/hud \
+    --system-curl \
+    --parallel=$(nproc) \
+    -- \
+    -DCMAKE_USE_OPENSSL=ON \
+    -DOPENSSL_ROOT_DIR=/opt/hud
 
 [build]
@@ -30,4 +26,4 @@
 
 [postinst]
-ldconfig 2>/dev/null || true
-echo "✓ CMake 4.1.0 installed to /opt/hud"
+echo "✓ cmake 3.31.0 installed to /opt/hud"
+/opt/hud/bin/cmake --version 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/cmake-4.1.0.huddef</code> (13 added, 17 removed)</summary>

```diff
--- pool/main/c/cmake/cmake-4.1.0.huddef
+++ sources/definitions/old/packages/cmake-4.1.0.huddef
@@ -1,5 +1,4 @@
-# HUD Package Definition - CMake 4.1.0
-# Modern build system generator - Based on LFS 12.4
-# Note: Can be built with minimal deps using bundled libraries
+# HUD Package Definition - cmake 4.1.0
+# Auto-generated for oVirt infrastructure
 
 Package: cmake
@@ -7,19 +6,10 @@
 Architecture: x86_64
 Section: development
-Depends: curl, libarchive, libuv, nghttp2
-Description: CMake - Cross-platform build system generator
+Depends: qt6,curl,libuv,git,sphinx,parallel-builds,mercurial,openjdk,gcc,subversion
+Description: CMake-4.1.0
 Source: https://cmake.org/files/v4.1/cmake-4.1.0.tar.gz
 
 [configure]
-# Fix lib64 issue
-sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
-
-# Bootstrap cmake - use system libs where available, bundle the rest
-./bootstrap --prefix=/opt/hud \
-            --mandir=/opt/hud/share/man \
-            --no-system-jsoncpp \
-            --no-system-cppdap \
-            --no-system-librhash \
-            --parallel=$(nproc)
+./configure --prefix=/opt/hud --parallel=$(nproc)
 
 [build]
@@ -27,7 +17,13 @@
 
 [install]
-make DESTDIR=$DESTDIR install
+make install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ CMake 4.1.0 installed to /opt/hud"
+echo "cmake 4.1.0 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `cups`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/c/cups/cups-2.4.12.huddef` | 2.4.12 | `b3c87ab23ce9` | `6eb28a075d99` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/cups-2.4.12.huddef` | 2.4.12 | `54ad470645bd` | `87bc4b55438f` | alt |
| `sources/definitions/old/updated-packages/cups-2.4.12.huddef` | 2.4.12 | `b3c87ab23ce9` | `6eb28a075d99` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/cups-2.4.12.huddef</code> (57 added, 5 removed)</summary>

```diff
--- pool/main/c/cups/cups-2.4.12.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/cups-2.4.12.huddef
@@ -1,15 +1,24 @@
 # HUD Package Definition - CUPS 2.4.12
 # Common Unix Printing System
+# Print spooler and utilities based on Internet Printing Protocol
 
 Package: cups
 Version: 2.4.12
 Architecture: x86_64
-Section: misc
-Depends: gnutls, libpng, libjpeg, libtiff, dbus, libusb
-Description: Common Unix Printing System
+Section: system
+Depends: gnutls, dbus, libusb, linux-pam
+Description: Common Unix Printing System - print spooler and associated utilities based on IPP
 Source: https://github.com/OpenPrinting/cups/releases/download/v2.4.12/cups-2.4.12-source.tar.gz
 
 [configure]
-./configure --prefix=/opt/hud --sysconfdir=/opt/hud/etc --localstatedir=/opt/hud/var --with-tls=gnutls --enable-libusb
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export LDFLAGS="-L/opt/hud/lib ${LDFLAGS}"
+export CFLAGS="-I/opt/hud/include ${CFLAGS}"
+
+./configure --prefix=/opt/hud            \
+            --libdir=/opt/hud/lib        \
+            --with-rundir=/run/cups      \
+            --with-system-groups=lpadmin \
+            --with-docdir=/opt/hud/share/cups/doc-2.4.12
 
 [build]
@@ -19,6 +28,49 @@
 make DESTDIR=$DESTDIR install
 
+# Create symlink for documentation
+ln -svnf ../cups/doc-2.4.12 $DESTDIR/opt/hud/share/doc/cups-2.4.12 2>/dev/null || true
+
+# Create PAM configuration
+mkdir -p $DESTDIR/etc/pam.d
+cat > $DESTDIR/etc/pam.d/cups << 'EOF'
+# Begin /etc/pam.d/cups
+
+auth    include system-auth
+account include system-account
+session include system-session
+
+# End /etc/pam.d/cups
+EOF
+
+# Create client configuration directory
+mkdir -p $DESTDIR/etc/cups
+
 [postinst]
+# Create lp user if not exists
+getent group lp >/dev/null || groupadd -g 7 lp
+getent passwd lp >/dev/null || useradd -c "Print Service User" -d /var/spool/cups \
+    -g lp -s /bin/false -u 9 lp
+
+# Create lpadmin group for administrative access
+getent group lpadmin >/dev/null || groupadd -g 19 lpadmin
+
+# Create required directories
+mkdir -p /var/spool/cups
+mkdir -p /var/log/cups
+mkdir -p /var/cache/cups
+mkdir -p /run/cups
+chown -R lp:lp /var/spool/cups
+chown -R lp:lp /var/log/cups
+chown -R lp:lp /var/cache/cups
+
+# Create client configuration
+echo "ServerName /run/cups/cups.sock" > /etc/cups/client.conf
+
+# Enable and start CUPS (socket activation)
+systemctl enable cups.socket 2>/dev/null || true
+systemctl enable cups.service 2>/dev/null || true
+
 ldconfig 2>/dev/null || true
-getent group lpadmin || groupadd -r lpadmin 2>/dev/null || true
 echo "✓ CUPS 2.4.12 installed to /opt/hud"
+echo "  Web interface: http://localhost:631"
+echo "  To add user to admin group: usermod -a -G lpadmin <username>"
```

</details>


### `curl`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/c/curl/curl-8.15.0.huddef` | 8.15.0 | `c136a1aef1f5` | `c8b6ea62f9f5` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/curl-8.15.0.huddef` | 8.15.0 | `d8f3ff02b82b` | `a1428502380b` | alt |
| `sources/definitions/old/packages/curl-8.15.0.huddef` | 8.15.0 | `c136a1aef1f5` | `c8b6ea62f9f5` | **= POOL** |
| `sources/definitions/old/packages/curl-8.6.0.huddef` | 8.6.0 | `cdc99a8f0121` | `3a511b64eb73` | alt |
| `sources/definitions/old/updated-packages/curl-8.15.0.huddef` | 8.15.0 | `c136a1aef1f5` | `c8b6ea62f9f5` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/curl-8.15.0.huddef</code> (18 added, 16 removed)</summary>

```diff
--- pool/main/c/curl/curl-8.15.0.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/curl-8.15.0.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - curl 8.15.0
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - cURL 8.15.0
+# URL Transfer Library and Tool
+# Command line tool and library for transferring data with URLs
 
 Package: curl
@@ -6,10 +7,15 @@
 Architecture: x86_64
 Section: network
-Depends: samba,nghttp2,apache,valgrind,openssh,gnutls,make-ca,brotli,libssh2,libpsl
-Description: cURL-8.15.0
+Depends: libpsl, openssl, zlib
+Description: Command line tool and library for transferring files with URL syntax supporting many protocols
 Source: https://curl.se/download/curl-8.15.0.tar.xz
 
 [configure]
-./configure --prefix=/opt/hud --with-openssl --enable-threaded-resolver --with-libssh2
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+
+./configure --prefix=/opt/hud    \
+            --disable-static     \
+            --with-openssl       \
+            --with-ca-path=/etc/ssl/certs
 
 [build]
@@ -17,20 +23,16 @@
 
 [install]
-make install &&
+make DESTDIR=$DESTDIR install
 
-rm -rf docs/examples/.deps &&
-
+# Clean up docs
+rm -rf docs/examples/.deps
 find docs \( -name Makefile\* -o  \
              -name \*.1       -o  \
              -name \*.3       -o  \
-             -name CMakeLists.txt \) -delete
+             -name CMakeLists.txt \) -delete 2>/dev/null || true
+
+cp -v -R docs -T $DESTDIR/opt/hud/share/doc/curl-8.15.0 2>/dev/null || true
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "curl 8.15.0 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ cURL 8.15.0 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/curl-8.6.0.huddef</code> (29 added, 22 removed)</summary>

```diff
--- pool/main/c/curl/curl-8.15.0.huddef
+++ sources/definitions/old/packages/curl-8.6.0.huddef
@@ -1,15 +1,29 @@
-# HUD Package Definition - curl 8.15.0
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - curl 8.6.0
+# Command line tool for transferring data with URLs
 
 Package: curl
-Version: 8.15.0
+Version: 8.6.0
 Architecture: x86_64
 Section: network
-Depends: samba,nghttp2,apache,valgrind,openssh,gnutls,make-ca,brotli,libssh2,libpsl
-Description: cURL-8.15.0
-Source: https://curl.se/download/curl-8.15.0.tar.xz
+Depends: openssl,zlib,nghttp2,libssh2,libidn2,brotli
+Description: Command line tool for transferring data with URLs
+Source: https://curl.se/download/curl-8.6.0.tar.gz
 
 [configure]
-./configure --prefix=/opt/hud --with-openssl --enable-threaded-resolver --with-libssh2
+./configure \
+    --prefix=/opt/hud \
+    --with-openssl=/opt/hud \
+    --with-zlib=/opt/hud \
+    --enable-ipv6 \
+    --enable-threaded-resolver \
+    --with-ca-bundle=/etc/pki/tls/certs/ca-bundle.crt \
+    --with-ca-path=/etc/pki/tls/certs \
+    --with-nghttp2=/opt/hud \
+    --with-libssh2=/opt/hud \
+    --with-libidn2=/opt/hud \
+    --with-brotli=/opt/hud \
+    PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig" \
+    LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 -Wl,-rpath,/opt/hud/lib -Wl,-rpath,/opt/hud/lib64" \
+    CPPFLAGS="-I/opt/hud/include"
 
 [build]
@@ -17,20 +31,13 @@
 
 [install]
-make install &&
-
-rm -rf docs/examples/.deps &&
-
-find docs \( -name Makefile\* -o  \
-             -name \*.1       -o  \
-             -name \*.3       -o  \
-             -name CMakeLists.txt \) -delete
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "curl 8.15.0 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+# Verify curl works
+if /opt/hud/bin/curl --version >/dev/null 2>&1; then
+    echo "✓ curl 8.6.0 installed successfully"
+    /opt/hud/bin/curl --version | head -1
+else
+    echo "✓ curl installed to /opt/hud/bin/curl"
+fi
```

</details>


### `cyrus-sasl`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/c/cyrus-sasl/cyrus-sasl-2.1.28.huddef` | 2.1.28 | `c32ac7e0e67a` | `22aa24ca34eb` | **POOL** |
| `sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/cyrus-sasl-2.1.28.huddef` | 2.1.28 | `3f962a529571` | `dce38ebec950` | alt |
| `sources/definitions/old/packages/cyrus-sasl-2.1.28.huddef` | 2.1.28 | `c32ac7e0e67a` | `22aa24ca34eb` | **= POOL** |
| `sources/definitions/old/updated-packages/cyrus-sasl-2.1.28.huddef` | 2.1.28 | `c32ac7e0e67a` | `22aa24ca34eb` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/cyrus-sasl-2.1.28.huddef</code> (69 added, 19 removed)</summary>

```diff
--- pool/main/c/cyrus-sasl/cyrus-sasl-2.1.28.huddef
+++ sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/cyrus-sasl-2.1.28.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - cyrus-sasl 2.1.28
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - Cyrus SASL 2.1.28
+# Simple Authentication and Security Layer
+# Fixed for GCC 15: Uses -std=gnu17 to allow K&R style functions
 
 Package: cyrus-sasl
@@ -6,30 +7,79 @@
 Architecture: x86_64
 Section: security
-Depends: bootscripts,linux-pam,postgresql,mariadb,lmdb,sqlite
-Description: Cyrus SASL-2.1.28
+Depends: lmdb, openssl
+Description: Simple Authentication and Security Layer implementation
 Source: https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-2.1.28/cyrus-sasl-2.1.28.tar.gz
-Service: saslauthd
 
 [configure]
-./configure --prefix=/opt/hud --sysconfdir=/opt/hud/etc --enable-auth-sasldb --with-dbpath=/opt/hud/etc/sasldb2
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+
+# GCC 15 defaults to C23 which rejects K&R style function definitions
+# Use -std=gnu17 to allow the old code to compile
+# Also disable -Werror=implicit-int which treats the warning as error
+export CFLAGS="${CFLAGS} -I/opt/hud/include -std=gnu17 -Wno-error=implicit-int -Wno-error=old-style-definition -Wno-error=implicit-function-declaration"
+
+export LDFLAGS="${LDFLAGS} -L/opt/hud/lib -L/opt/hud/lib64"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+
+# Fix time.h includes for glibc compatibility
+sed -i '/saslint/a #include <time.h>' lib/saslutil.c
+sed -i '/plugin_common/a #include <time.h>' plugins/cram.c
+
+# Regenerate configure
+autoreconf -fiv 2>/dev/null || autoreconf -fi 2>/dev/null || true
+
+./configure --prefix=/opt/hud                        \
+            --sysconfdir=/opt/hud/etc                \
+            --enable-auth-sasldb                     \
+            --with-dblib=lmdb                        \
+            --with-dbpath=/var/lib/sasl/sasldb2      \
+            --with-saslauthd=/run/saslauthd          \
+            --with-openssl=/opt/hud                  \
+            --disable-static                         \
+            --enable-shared                          \
+            CFLAGS="${CFLAGS}"
 
 [build]
-make -j$(nproc)
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+# Cyrus SASL does not support parallel build
+make -j1
 
 [install]
-make install &&
-install -v -dm755                          /usr/share/doc/cyrus-sasl-2.1.28/html &&
-install -v -m644  saslauthd/LDAP_SASLAUTHD /usr/share/doc/cyrus-sasl-2.1.28      &&
-install -v -m644
+make DESTDIR=$DESTDIR install
+install -vdm755 $DESTDIR/opt/hud/share/doc/cyrus-sasl-2.1.28/html
+install -vm644 saslauthd/LDAP_SASLAUTHD $DESTDIR/opt/hud/share/doc/cyrus-sasl-2.1.28/ 2>/dev/null || true
+install -vm644 doc/legacy/*.html $DESTDIR/opt/hud/share/doc/cyrus-sasl-2.1.28/html/ 2>/dev/null || true
+install -vdm700 $DESTDIR/var/lib/sasl
+
+# Install systemd service for saslauthd
+install -vdm755 $DESTDIR/etc/systemd/system
+cat > $DESTDIR/etc/systemd/system/saslauthd.service << 'SVCEOF'
+[Unit]
+Description=SASL Authentication Daemon
+After=network.target
+
+[Service]
+Type=forking
+PIDFile=/run/saslauthd/saslauthd.pid
+ExecStart=/opt/hud/sbin/saslauthd -a shadow -m /run/saslauthd
+ExecReload=/bin/kill -HUP $MAINPID
+RuntimeDirectory=saslauthd
+
+[Install]
+WantedBy=multi-user.target
+SVCEOF
 
 [postinst]
-ldconfig 2>/dev/null || true
-echo "cyrus-sasl 2.1.28 installed to /opt/hud"
+ldconfig
+install -vdm700 /var/lib/sasl 2>/dev/null || true
+install -vdm755 /run/saslauthd 2>/dev/null || true
 
-[prerm]
-# Stop service if running
-systemctl stop hud-saslauthd 2>/dev/null || true
-systemctl disable hud-saslauthd 2>/dev/null || true
+# Reload systemd if available
+systemctl daemon-reload 2>/dev/null || true
 
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ Cyrus SASL 2.1.28 installed to /opt/hud"
+echo ""
+echo "To start saslauthd daemon:"
+echo "  systemctl enable --now saslauthd"
```

</details>


### `dbus`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/d/dbus/dbus-1.16.2.huddef` | 1.16.2 | `bcb986fff6cb` | `8b12c43f689d` | **POOL** |
| `sources/definitions/old/1 Feb 2026/dbus-1.16.2.huddef` | 1.16.2 | `d43dfc8946f7` | `fef16b3053d0` | alt |
| `sources/definitions/old/packages/dbus-1.16.0.huddef` | 1.16.0 | `54db57dfc35c` | `c7c53458a37e` | alt |
| `sources/definitions/old/packages/dbus-1.16.2.huddef` | 1.16.2 | `91694f452095` | `096f0a77c9ba` | alt |
| `sources/definitions/old/updated-packages/dbus-1.16.2.huddef` | 1.16.2 | `bcb986fff6cb` | `8b12c43f689d` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/dbus-1.16.2.huddef</code> (65 added, 8 removed)</summary>

```diff
--- pool/main/d/dbus/dbus-1.16.2.huddef
+++ sources/definitions/old/1 Feb 2026/dbus-1.16.2.huddef
@@ -1,23 +1,80 @@
-# HUD Package Definition - dbus 1.16.2
-# D-Bus message bus system
+# HUD Package Definition - D-Bus 1.16.2
+# Message Bus System
+# Inter-process communication system for software applications
+# Fixed: Creates symlink from /run/dbus to /opt/hud socket for compatibility
+
 Package: dbus
 Version: 1.16.2
 Architecture: x86_64
 Section: system
-Depends: xorg-libraries
-Description: D-Bus message bus system for interprocess communication
+Depends: expat
+Description: Message bus system for inter-process communication between applications
 Source: https://dbus.freedesktop.org/releases/dbus/dbus-1.16.2.tar.xz
+
 [configure]
 mkdir -p build
 cd build
-meson setup --prefix=/opt/hud --buildtype=release --wrap-mode=nofallback ..
+
+meson setup ..                     \
+    --prefix=/opt/hud              \
+    --buildtype=release            \
+    --wrap-mode=nofallback         \
+    -D system_socket=/opt/hud/var/run/dbus/system_bus_socket \
+    -D dbus_user=messagebus
+
 [build]
 cd build
 ninja
+
 [install]
 cd build
 DESTDIR=$DESTDIR ninja install
+
+# Create tmpfiles.d configuration for socket symlink (standard location compatibility)
+mkdir -p $DESTDIR/etc/tmpfiles.d
+cat > $DESTDIR/etc/tmpfiles.d/dbus-socket-compat.conf << 'EOF'
+# D-Bus socket compatibility symlink
+# Creates /run/dbus/system_bus_socket -> /opt/hud/var/run/dbus/system_bus_socket
+# Required for systemd-logind and other services expecting standard socket path
+d /run/dbus 0755 root root -
+L+ /run/dbus/system_bus_socket - - - - /opt/hud/var/run/dbus/system_bus_socket
+EOF
+
+# Create systemd service drop-in for socket symlink
+mkdir -p $DESTDIR/etc/systemd/system/dbus.service.d
+cat > $DESTDIR/etc/systemd/system/dbus.service.d/socket-symlink.conf << 'EOF'
+[Service]
+# Ensure /run/dbus exists and symlink points to actual socket
+ExecStartPre=-/bin/mkdir -p /run/dbus
+ExecStartPre=-/bin/ln -sf /opt/hud/var/run/dbus/system_bus_socket /run/dbus/system_bus_socket
+EOF
+
 [postinst]
-echo "✓ dbus 1.16.2 installed to /opt/hud"
-chown -v root:messagebus /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
-chmod -v 4750 /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
+# Create messagebus user/group if not exists
+getent group messagebus >/dev/null || groupadd -g 18 messagebus
+getent passwd messagebus >/dev/null || useradd -c "D-Bus Message Daemon User" -d /run/dbus \
+    -u 18 -g messagebus -s /bin/false messagebus
+
+# Create runtime directories
+mkdir -p /opt/hud/var/run/dbus
+mkdir -p /run/dbus
+chown messagebus:messagebus /opt/hud/var/run/dbus
+
+# Create socket symlink for standard path compatibility
+# systemd-logind and other services expect socket at /run/dbus/system_bus_socket
+ln -sf /opt/hud/var/run/dbus/system_bus_socket /run/dbus/system_bus_socket
+
+# Fix permissions on helper binary
+chown root:messagebus /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
+chmod 4750 /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
+
+# Apply tmpfiles configuration
+systemd-tmpfiles --create /etc/tmpfiles.d/dbus-socket-compat.conf 2>/dev/null || true
+
+# Reload systemd to pick up drop-in
+systemctl daemon-reload 2>/dev/null || true
+
+ldconfig 2>/dev/null || true
+echo "✓ D-Bus 1.16.2 installed to /opt/hud"
+echo "  Socket: /opt/hud/var/run/dbus/system_bus_socket"
+echo "  Symlink: /run/dbus/system_bus_socket -> /opt/hud/var/run/dbus/system_bus_socket"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/dbus-1.16.0.huddef</code> (56 added, 16 removed)</summary>

```diff
--- pool/main/d/dbus/dbus-1.16.2.huddef
+++ sources/definitions/old/packages/dbus-1.16.0.huddef
@@ -1,23 +1,63 @@
-# HUD Package Definition - dbus 1.16.2
-# D-Bus message bus system
+# HUD Package Definition - dbus 1.16.0
+# Message bus system
+
 Package: dbus
-Version: 1.16.2
+Version: 1.16.0
 Architecture: x86_64
 Section: system
-Depends: xorg-libraries
-Description: D-Bus message bus system for interprocess communication
-Source: https://dbus.freedesktop.org/releases/dbus/dbus-1.16.2.tar.xz
+Depends: expat,glib2
+Description: D-Bus message bus system
+Source: https://dbus.freedesktop.org/releases/dbus/dbus-1.16.0.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release --wrap-mode=nofallback ..
+./configure \
+    --prefix=/opt/hud \
+    --sysconfdir=/opt/hud/etc \
+    --localstatedir=/opt/hud/var \
+    --runstatedir=/run \
+    --disable-static \
+    --disable-doxygen-docs \
+    --disable-xml-docs \
+    --with-systemdsystemunitdir=/opt/hud/lib/systemd/system \
+    --with-system-socket=/run/dbus/system_bus_socket \
+    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
+    CPPFLAGS="-I/opt/hud/include"
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make DESTDIR=$DESTDIR install
+# Create dbus user/group helper script
+mkdir -p $DESTDIR/opt/hud/share/hud/setup
+cat > $DESTDIR/opt/hud/share/hud/setup/dbus-setup.sh << 'DBUSSETUP'
+#!/bin/bash
+# Create messagebus user/group if not exists
+getent group messagebus >/dev/null || groupadd -r messagebus
+getent passwd messagebus >/dev/null || useradd -r -g messagebus -d / -s /sbin/nologin -c "D-Bus System Message Bus" messagebus
+mkdir -p /run/dbus
+chown messagebus:messagebus /run/dbus
+DBUSSETUP
+chmod +x $DESTDIR/opt/hud/share/hud/setup/dbus-setup.sh
+
 [postinst]
-echo "✓ dbus 1.16.2 installed to /opt/hud"
-chown -v root:messagebus /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
-chmod -v 4750 /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
+ldconfig 2>/dev/null || true
+# Run setup script
+if [ -x /opt/hud/share/hud/setup/dbus-setup.sh ]; then
+    /opt/hud/share/hud/setup/dbus-setup.sh 2>/dev/null || true
+fi
+# Generate machine-id if needed
+if [ ! -f /opt/hud/var/lib/dbus/machine-id ] && [ ! -f /etc/machine-id ]; then
+    mkdir -p /opt/hud/var/lib/dbus
+    /opt/hud/bin/dbus-uuidgen --ensure=/opt/hud/var/lib/dbus/machine-id
+fi
+echo "✓ dbus 1.16.0 installed to /opt/hud"
+
+[prerm]
+systemctl stop hud-dbus 2>/dev/null || true
+
+[postrm]
+ldconfig 2>/dev/null || true
+
+[service]
+dbus
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/dbus-1.16.2.huddef</code> (20 added, 14 removed)</summary>

```diff
--- pool/main/d/dbus/dbus-1.16.2.huddef
+++ sources/definitions/old/packages/dbus-1.16.2.huddef
@@ -1,23 +1,29 @@
 # HUD Package Definition - dbus 1.16.2
-# D-Bus message bus system
+# Auto-generated for oVirt infrastructure
+
 Package: dbus
 Version: 1.16.2
 Architecture: x86_64
-Section: system
-Depends: xorg-libraries
-Description: D-Bus message bus system for interprocess communication
+Section: misc
+Depends: bootscripts,valgrind,doxygen,dbus-python,elogind,xorg7-lib,pygobject3
+Description: dbus-1.16.2
 Source: https://dbus.freedesktop.org/releases/dbus/dbus-1.16.2.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release --wrap-mode=nofallback ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ dbus 1.16.2 installed to /opt/hud"
-chown -v root:messagebus /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
-chmod -v 4750 /opt/hud/libexec/dbus-daemon-launch-helper 2>/dev/null || true
+ldconfig 2>/dev/null || true
+echo "dbus 1.16.2 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `dtc`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/d/dtc/dtc-1.7.2.huddef` | 1.7.2 | `cdb6902b18be` | `54dee2f3f044` | **POOL** |
| `sources/definitions/old/packages/dtc-1.7.2.huddef` | 1.7.2 | `b69bdfafe0e8` | `695944f7f3a6` | alt |
| `sources/definitions/old/updated-packages/dtc-1.7.2.huddef` | 1.7.2 | `501266929615` | `7046c412b3f5` | alt |
| `sources/definitions/qemu-huddef/dtc-1.7.2.huddef` | 1.7.2 | `cdb6902b18be` | `54dee2f3f044` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/dtc-1.7.2.huddef</code> (22 added, 22 removed)</summary>

```diff
--- pool/main/d/dtc/dtc-1.7.2.huddef
+++ sources/definitions/old/packages/dtc-1.7.2.huddef
@@ -1,29 +1,29 @@
-# HUD Package Definition - DTC 1.7.2
-# Device Tree Compiler (required for QEMU)
-# Without this, QEMU build will attempt to download from Internet
+# HUD Package Definition - dtc 1.7.2
+# Auto-generated for oVirt infrastructure
+
 Package: dtc
 Version: 1.7.2
 Architecture: x86_64
-Section: development
-Depends: glib
-Description: Device Tree Compiler for producing device tree binary files
-Source: https://www.kernel.org/pub/software/utils/dtc/dtc-1.7.2.tar.xz
+Section: misc
+Depends: 
+Description: dtc-1.7.2
+Source: https://kernel.org/pub/software/utils/dtc/dtc-1.7.2.tar.xz
+
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-# DTC uses meson build system
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud ..
+./configure --prefix=/opt/hud
+
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-ldconfig
-echo "✓ DTC (Device Tree Compiler) 1.7.2 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "dtc 1.7.2 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/updated-packages/dtc-1.7.2.huddef</code> (17 added, 22 removed)</summary>

```diff
--- pool/main/d/dtc/dtc-1.7.2.huddef
+++ sources/definitions/old/updated-packages/dtc-1.7.2.huddef
@@ -1,29 +1,24 @@
-# HUD Package Definition - DTC 1.7.2
-# Device Tree Compiler (required for QEMU)
-# Without this, QEMU build will attempt to download from Internet
+# HUD Package Definition - dtc 1.7.2
+# Device Tree Compiler
+
 Package: dtc
 Version: 1.7.2
 Architecture: x86_64
-Section: development
-Depends: glib
-Description: Device Tree Compiler for producing device tree binary files
-Source: https://www.kernel.org/pub/software/utils/dtc/dtc-1.7.2.tar.xz
+Section: misc
+Description: Device Tree Compiler for working with device tree source and binary files
+Source: https://kernel.org/pub/software/utils/dtc/dtc-1.7.2.tar.xz
+MD5sum: 0f193be84172556027da22d4fe3464e0
+
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-# DTC uses meson build system
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud ..
+mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release -Dpython=disabled ..
+
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
-ninja
+cd build && ninja -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+cd build && DESTDIR=$DESTDIR ninja install
+rm -f $DESTDIR/opt/hud/lib/libfdt.a
+
 [postinst]
-ldconfig
-echo "✓ DTC (Device Tree Compiler) 1.7.2 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "✓ dtc 1.7.2 installed to /opt/hud"
```

</details>


### `duktape`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/d/duktape/duktape-2.7.0.huddef` | 2.7.0 | `66db8d7b1743` | `62a49bf83c92` | **POOL** |
| `sources/definitions/old/1 Feb 2026/duktape-2.7.0.huddef` | 2.7.0 | `a48c0f459835` | `2cf2a1ef5063` | alt |
| `sources/definitions/old/packages/duktape-2.7.0.huddef` | 2.7.0 | `66db8d7b1743` | `62a49bf83c92` | **= POOL** |
| `sources/definitions/old/updated-packages/duktape-2.7.0.huddef` | 2.7.0 | `66db8d7b1743` | `62a49bf83c92` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/duktape-2.7.0.huddef</code> (10 added, 20 removed)</summary>

```diff
--- pool/main/d/duktape/duktape-2.7.0.huddef
+++ sources/definitions/old/1 Feb 2026/duktape-2.7.0.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - duktape 2.7.0
-# Embeddable JavaScript engine
+# HUD Package Definition - Duktape 2.7.0
+# Embeddable Javascript Engine
+# Lightweight JS engine with focus on portability and compact footprint
 
 Package: duktape
@@ -7,30 +8,19 @@
 Section: libraries
 Depends:
-Description: Embeddable JavaScript engine
+Description: Embeddable Javascript engine with focus on portability and compact footprint
 Source: https://duktape.org/duktape-2.7.0.tar.xz
 
+[configure]
+# Duktape uses a simple Makefile, no configure step needed
+# Fix optimization flag from -Os to -O2 for better performance
+sed -i 's/-Os/-O2/' Makefile.sharedlibrary
+
 [build]
-# Build shared library
-sed -i 's/-Os/-O2/' Makefile.sharedlibrary
 make -f Makefile.sharedlibrary INSTALL_PREFIX=/opt/hud
 
 [install]
 make -f Makefile.sharedlibrary INSTALL_PREFIX=/opt/hud DESTDIR=$DESTDIR install
-# Create pkg-config file
-mkdir -p $DESTDIR/opt/hud/lib/pkgconfig
-cat > $DESTDIR/opt/hud/lib/pkgconfig/duktape.pc << 'DUKTAPEPC'
-prefix=/opt/hud
-exec_prefix=${prefix}
-libdir=${exec_prefix}/lib
-includedir=${prefix}/include
-
-Name: Duktape
-Description: Embeddable JavaScript engine
-Version: 2.7.0
-Libs: -L${libdir} -lduktape -lm
-Cflags: -I${includedir}
-DUKTAPEPC
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ duktape 2.7.0 installed to /opt/hud"
+echo "✓ Duktape 2.7.0 installed to /opt/hud"
```

</details>


### `firewalld`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/f/firewalld/firewalld-2.3.2.huddef` | 2.3.2 | `d15f7fd90edc` | `f79a6e7c24ae` | **POOL** |
| `sources/definitions/13 Feb 2026/firewalld-2.3.2.huddef` | 2.3.2 | `d15f7fd90edc` | `f79a6e7c24ae` | **= POOL** |
| `sources/definitions/libvirt/firewalld-2.3.2.huddef` | 2.3.2 | `e6a0ad6168ce` | `0f0e2d54dbf0` | alt |
| `sources/definitions/libvirt_9feb_2026/firewalld-2.3.2.huddef` | 2.3.2 | `d15f7fd90edc` | `f79a6e7c24ae` | **= POOL** |

<details><summary>diff → <code>sources/definitions/libvirt/firewalld-2.3.2.huddef</code> (4 added, 83 removed)</summary>

```diff
--- pool/main/f/firewalld/firewalld-2.3.2.huddef
+++ sources/definitions/libvirt/firewalld-2.3.2.huddef
@@ -1,13 +1,5 @@
 # HUD Package Definition - firewalld 2.3.2
 # Dynamic firewall daemon with D-Bus interface
-# Uses nftables backend for libvirt compatibility
 # Reference: https://firewalld.org/
-#
-# FIXES APPLIED:
-# - Wrapper script for firewall-cmd with PYTHONPATH
-# - nftables backend configuration
-# - Disabled problematic options (NftablesTableOwner, RFC3964_IPv4, IPv6_rpfilter)
-# - Creates libvirt zone for virtual networking
-# - Proper systemd service with environment variables
 
 Package: firewalld
@@ -15,5 +7,5 @@
 Architecture: x86_64
 Section: network
-Depends: python3, dbus, dbus-python, pygobject, glib, iptables, polkit, libxml2, nftables
+Depends: python3, dbus, dbus-python, pygobject, glib, iptables, polkit, libxml2
 Description: Dynamic firewall daemon with D-Bus interface
 Source: https://github.com/firewalld/firewalld/releases/download/v2.3.2/firewalld-2.3.2.tar.bz2
@@ -41,89 +33,18 @@
 [postinst]
 ldconfig
-
-# Create directories
 install -vdm755 /etc/firewalld
 install -vdm755 /etc/firewalld/zones
 install -vdm755 /etc/firewalld/services
 install -vdm755 /var/lib/firewalld
-
-# Symlink firewalld data files
 ln -sf /opt/hud/lib/firewalld /usr/lib/firewalld 2>/dev/null || true
+ln -sf /opt/hud/bin/firewall-cmd /usr/bin/firewall-cmd 2>/dev/null || true
 ln -sf /opt/hud/sbin/firewalld /usr/sbin/firewalld 2>/dev/null || true
-
-# Create wrapper script for firewall-cmd with proper PYTHONPATH
-cat > /usr/bin/firewall-cmd << 'EOFWRAP'
-#!/bin/bash
-export PYTHONPATH=/opt/hud/lib/python3.13/site-packages
-exec /opt/hud/bin/firewall-cmd "$@"
-EOFWRAP
-chmod +x /usr/bin/firewall-cmd
-
-# Create firewalld config with nftables backend and disabled problematic options
-cat > /etc/firewalld/firewalld.conf << 'EOFCONF'
-# firewalld configuration
-DefaultZone=public
-CleanupOnExit=yes
-CleanupModulesOnExit=no
-IPv6_rpfilter=no
-IndividualCalls=no
-LogDenied=off
-FirewallBackend=nftables
-FlushAllOnReload=yes
-RFC3964_IPv4=no
-NftablesTableOwner=no
-NftablesCounters=no
-EOFCONF
-
-# Create libvirt zone for virtual networking
-cat > /etc/firewalld/zones/libvirt.xml << 'EOFXML'
-<?xml version="1.0" encoding="utf-8"?>
-<zone target="ACCEPT">
-  <short>libvirt</short>
-  <description>The libvirt zone for virtual networks. Used by libvirt for NAT and routed virtual networks.</description>
-</zone>
-EOFXML
-
-# Create systemd service with all required environment variables
-cat > /etc/systemd/system/firewalld.service << 'EOFSVC'
-[Unit]
-Description=firewalld - dynamic firewall daemon
-Before=network-pre.target
-Wants=network-pre.target
-After=dbus.service
-After=polkit.service
-After=local-fs.target
-Conflicts=iptables.service ip6tables.service ebtables.service ipset.service nftables.service
-Documentation=man:firewalld(1)
-
-[Service]
-Environment=PYTHONPATH=/opt/hud/lib/python3.13/site-packages
-Environment=LD_LIBRARY_PATH=/opt/hud/lib:/opt/hud/lib64
-Environment=PATH=/opt/hud/sbin:/opt/hud/bin:/usr/sbin:/usr/bin:/sbin:/bin
-EnvironmentFile=-/etc/sysconfig/firewalld
-ExecStart=/opt/hud/sbin/firewalld --nofork --nopid $FIREWALLD_ARGS
-ExecReload=/bin/kill -HUP $MAINPID
-Type=dbus
-BusName=org.fedoraproject.FirewallD1
-KillMode=mixed
-TimeoutStartSec=60
-Restart=on-failure
-RestartSec=5
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
+printf 'DefaultZone=public\nCleanupOnExit=yes\nCleanupModulesOnExit=no\nIPv6_rpfilter=no\nIndividualCalls=no\nLogDenied=off\nFirewallBackend=nftables\nFlushAllOnReload=yes\nRFC3964_IPv4=no\nNftablesTableOwner=no\nNftablesCounters=no\n' > /etc/firewalld/firewalld.conf
+printf '[Unit]\nDescription=firewalld - dynamic firewall daemon\nBefore=network-pre.target\nWants=network-pre.target\nAfter=dbus.service\nAfter=polkit.service\nConflicts=iptables.service ip6tables.service ebtables.service ipset.service nftables.service\nDocumentation=man:firewalld(1)\n\n[Service]\nEnvironment=PYTHONPATH=/opt/hud/lib/python3.13/site-packages\nEnvironment=LD_LIBRARY_PATH=/opt/hud/lib:/opt/hud/lib64\nEnvironment=PATH=/opt/hud/sbin:/opt/hud/bin:/usr/sbin:/usr/bin:/sbin:/bin\nEnvironmentFile=-/etc/sysconfig/firewalld\nExecStart=/opt/hud/sbin/firewalld --nofork --nopid $FIREWALLD_ARGS\nExecReload=/bin/kill -HUP $MAINPID\nType=dbus\nBusName=org.fedoraproject.FirewallD1\nKillMode=mixed\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/firewalld.service
 systemctl daemon-reload
 systemctl enable firewalld.service || true
 systemctl start firewalld.service || true
-
-echo ""
 echo "firewalld 2.3.2 installed"
 echo "Commands: firewall-cmd, firewalld"
-echo ""
 echo "Status: firewall-cmd --state"
-echo "Zones:  firewall-cmd --get-zones"
-echo "Reload: firewall-cmd --reload"
-echo ""
 echo "Service enabled and started automatically"
```

</details>


### `fontconfig`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/f/fontconfig/fontconfig-2.17.1.huddef` | 2.17.1 | `cc30cb6c20a7` | `5dd26cd0422e` | **POOL** |
| `sources/definitions/old/0/fontconfig-2.17.1.huddef` | 2.17.1 | `39d43cde0a9d` | `2535a2989892` | alt |
| `sources/definitions/old/packages/fontconfig-2.17.1.huddef` | 2.17.1 | `cc30cb6c20a7` | `5dd26cd0422e` | **= POOL** |
| `sources/definitions/old/updated-packages/fontconfig-2.17.1.huddef` | 2.17.1 | `cc30cb6c20a7` | `5dd26cd0422e` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/fontconfig-2.17.1.huddef</code> (9 added, 20 removed)</summary>

```diff
--- pool/main/f/fontconfig/fontconfig-2.17.1.huddef
+++ sources/definitions/old/0/fontconfig-2.17.1.huddef
@@ -1,29 +1,18 @@
 # HUD Package Definition - fontconfig 2.17.1
-# Auto-generated for oVirt infrastructure
-
+# Library for configuring and customizing font access
 Package: fontconfig
 Version: 2.17.1
 Architecture: x86_64
-Section: misc
-Depends: tl-installer,freetype2,curl,json-c,bubblewrap,make-ca,texlive,libxml2
-Description: Fontconfig-2.17.1
+Section: graphics
+Depends: freetype
+Description: Library and support programs for configuring and customizing font access
 Source: https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.17.1/fontconfig-2.17.1.tar.xz
-
 [configure]
-./configure --prefix=/opt/hud
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-docs --docdir=/opt/hud/share/doc/fontconfig-2.17.1
 [build]
-make -j$(nproc)
-
+make
 [install]
-make install
-
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
-echo "fontconfig 2.17.1 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ fontconfig 2.17.1 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `fribidi`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/f/fribidi/fribidi-1.0.16.huddef` | 1.0.16 | `deb743a4241a` | `095dd5dd1e17` | **POOL** |
| `sources/definitions/old/0/fribidi-1.0.16.huddef` | 1.0.16 | `deb743a4241a` | `095dd5dd1e17` | **= POOL** |
| `sources/definitions/old/packages/fribidi-1.0.16.huddef` | 1.0.16 | `24f6e9434551` | `bd17498b9f5f` | alt |
| `sources/definitions/old/updated-packages/fribidi-1.0.16.huddef` | 1.0.16 | `deb743a4241a` | `095dd5dd1e17` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/fribidi-1.0.16.huddef</code> (20 added, 13 removed)</summary>

```diff
--- pool/main/f/fribidi/fribidi-1.0.16.huddef
+++ sources/definitions/old/packages/fribidi-1.0.16.huddef
@@ -1,22 +1,29 @@
 # HUD Package Definition - fribidi 1.0.16
-# Unicode Bidirectional Algorithm library
+# Auto-generated for oVirt infrastructure
+
 Package: fribidi
 Version: 1.0.16
 Architecture: x86_64
-Section: graphics
-Depends:
-Description: Implementation of the Unicode Bidirectional Algorithm
+Section: misc
+Depends: 
+Description: FriBidi-1.0.16
 Source: https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ fribidi 1.0.16 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "fribidi 1.0.16 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `gdk-pixbuf`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/0/gdk-pixbuf-2.42.12.huddef` | 2.42.12 | `455e9d9f1348` | `f298a4a324b6` | alt |
| `sources/definitions/old/packages/gdk-pixbuf-2.42.12.huddef` | 2.42.12 | `3fe23d32fb37` | `592ac9da38d3` | alt |
| `sources/definitions/old/updated-packages/gdk-pixbuf-2.42.12.huddef` | 2.42.12 | `3fe23d32fb37` | `592ac9da38d3` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/0/gdk-pixbuf-2.42.12.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/gdk-pixbuf-2.42.12.huddef</code> (20 added, 14 removed)</summary>

```diff
--- sources/definitions/old/0/gdk-pixbuf-2.42.12.huddef
+++ sources/definitions/old/packages/gdk-pixbuf-2.42.12.huddef
@@ -1,23 +1,29 @@
 # HUD Package Definition - gdk-pixbuf 2.42.12
-# Image loading library
+# Auto-generated for oVirt infrastructure
+
 Package: gdk-pixbuf
 Version: 2.42.12
 Architecture: x86_64
-Section: graphics
-Depends: glib,libpng,libjpeg-turbo,libtiff,shared-mime-info
-Description: Image loading library for GTK+
+Section: misc
+Depends: gi-docgen,libtiff,glib2,libjxl,docutils,libjpeg,libpng,libavif
+Description: gdk-pixbuf-2.42.12
 Source: https://download.gnome.org/sources/gdk-pixbuf/2.42/gdk-pixbuf-2.42.12.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release -Dman=false ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ gdk-pixbuf 2.42.12 installed to /opt/hud"
-/sbin/ldconfig
-gdk-pixbuf-query-loaders --update-cache 2>/dev/null || true
+ldconfig 2>/dev/null || true
+echo "gdk-pixbuf 2.42.12 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `giflib`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/g/giflib/giflib-5.2.2.huddef` | 5.2.2 | `c44b87eb7087` | `98045d5fbf8c` | **POOL** |
| `sources/definitions/old/packages/giflib-5.2.2.huddef` | 5.2.2 | `95f429da6784` | `a69cc17c81b9` | alt |
| `sources/definitions/old/updated-packages/giflib-5.2.2.huddef` | 5.2.2 | `c44b87eb7087` | `98045d5fbf8c` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/giflib-5.2.2.huddef</code> (12 added, 18 removed)</summary>

```diff
--- pool/main/g/giflib/giflib-5.2.2.huddef
+++ sources/definitions/old/packages/giflib-5.2.2.huddef
@@ -1,5 +1,4 @@
 # HUD Package Definition - giflib 5.2.2
-# GIF image library - Based on LFS 12.4
-# Note: Uses plain Makefile, requires patches
+# Auto-generated for oVirt infrastructure
 
 Package: giflib
@@ -7,19 +6,10 @@
 Architecture: x86_64
 Section: libraries
-Depends:
-Description: Library for reading and writing GIF images
+Depends: 
+Description: giflib-5.2.2
 Source: https://sourceforge.net/projects/giflib/files/giflib-5.2.2.tar.gz
 
 [configure]
-# Download and apply required patches
-wget -q https://www.linuxfromscratch.org/patches/blfs/12.4/giflib-5.2.2-upstream_fixes-1.patch -O ../upstream_fixes.patch
-wget -q https://www.linuxfromscratch.org/patches/blfs/12.4/giflib-5.2.2-security_fixes-1.patch -O ../security_fixes.patch
-
-# Apply patches
-patch -Np1 -i ../upstream_fixes.patch
-patch -Np1 -i ../security_fixes.patch
-
-# Move file to expected location (removes ImageMagick dependency)
-cp pic/gifgrid.gif doc/giflib-logo.gif
+./configure --prefix=/opt/hud
 
 [build]
@@ -27,9 +17,13 @@
 
 [install]
-make PREFIX=/opt/hud DESTDIR=$DESTDIR install
-# Remove static library
-rm -fv $DESTDIR/opt/hud/lib/libgif.a
+make install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ giflib 5.2.2 installed to /opt/hud"
+echo "giflib 5.2.2 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `glib`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/g/glib/glib-2.84.4.huddef` | 2.84.4 | `4e3205bb940a` | `25fb244f5504` | **POOL** |
| `sources/definitions/glib/glib-2.84.4-stage1.huddef` | 2.84.4 | `4255bb4a8cb7` | `17f009eefdcb` | alt |
| `sources/definitions/glib/glib-2.84.4-stage2.huddef` | 2.84.4 | `4328e961b32c` | `7e26f3332cbc` | alt |
| `sources/definitions/old/0/glib-2.84.4.huddef` | 2.84.4 | `4e3205bb940a` | `25fb244f5504` | **= POOL** |
| `sources/definitions/old/updated-packages/glib-2.84.4.huddef` | 2.84.4 | `4e3205bb940a` | `25fb244f5504` | **= POOL** |

<details><summary>diff → <code>sources/definitions/glib/glib-2.84.4-stage1.huddef</code> (36 added, 7 removed)</summary>

```diff
--- pool/main/g/glib/glib-2.84.4.huddef
+++ sources/definitions/glib/glib-2.84.4-stage1.huddef
@@ -1,22 +1,51 @@
-# HUD Package Definition - glib 2.84.4
-# Low-level core library for GTK+ and GNOME
+# HUD Package Definition - GLib 2.84.4 (Stage 1)
+# Core library for GNOME/GTK applications
+# Stage 1: Build WITHOUT introspection to bootstrap the dependency chain
+
 Package: glib
 Version: 2.84.4
 Architecture: x86_64
 Section: libraries
-Depends: pcre2,libffi,python3,meson,ninja
-Description: Low-level core library that forms the basis for GTK+ and GNOME
+Depends: libffi, pcre2, python3
+Description: Low-level core library for GNOME/GTK (bootstrap without introspection)
 Source: https://download.gnome.org/sources/glib/2.84/glib-2.84.4.tar.xz
+
 [configure]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+export CFLAGS="-I/opt/hud/include"
+export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
+export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share"
+
 mkdir -p build
 cd build
-meson setup --prefix=/opt/hud --buildtype=release -Dman-pages=disabled -Dtests=false ..
+
+meson setup ..                       \
+      --prefix=/opt/hud              \
+      --buildtype=release            \
+      -D introspection=disabled      \
+      -D man-pages=disabled          \
+      -D tests=false
+
 [build]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share"
 cd build
 ninja
+
 [install]
 cd build
 DESTDIR=$DESTDIR ninja install
+
 [postinst]
-echo "✓ glib 2.84.4 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig
+echo "═══════════════════════════════════════════════════════════"
+echo "  GLib 2.84.4 Stage 1 Complete (without introspection)"
+echo "═══════════════════════════════════════════════════════════"
+echo ""
+echo "Next steps:"
+echo "  1. Run: hud-build gobject-introspection-1.84.0-rebuild.huddef"
+echo "  2. Run: hud-build glib-2.84.4-stage2.huddef"
+echo ""
```

</details>

<details><summary>diff → <code>sources/definitions/glib/glib-2.84.4-stage2.huddef</code> (82 added, 7 removed)</summary>

```diff
--- pool/main/g/glib/glib-2.84.4.huddef
+++ sources/definitions/glib/glib-2.84.4-stage2.huddef
@@ -1,22 +1,97 @@
-# HUD Package Definition - glib 2.84.4
-# Low-level core library for GTK+ and GNOME
+# HUD Package Definition - GLib 2.84.4 (Stage 2 - Final)
+# Core library for GNOME/GTK applications
+# Stage 2: Build WITH introspection support (full build)
+# Run this AFTER gobject-introspection-1.84.0-rebuild.huddef
+
 Package: glib
 Version: 2.84.4
 Architecture: x86_64
 Section: libraries
-Depends: pcre2,libffi,python3,meson,ninja
-Description: Low-level core library that forms the basis for GTK+ and GNOME
+Depends: libffi, pcre2, python3, gobject-introspection
+Description: Low-level core library for GNOME/GTK with full introspection support
 Source: https://download.gnome.org/sources/glib/2.84/glib-2.84.4.tar.xz
+
 [configure]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+export CFLAGS="-I/opt/hud/include"
+export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
+export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share"
+
+# GObject Introspection environment
+export GI_TYPELIB_PATH="/opt/hud/lib/girepository-1.0:/opt/hud/lib64/girepository-1.0"
+export GI_GIR_PATH="/opt/hud/share/gir-1.0"
+
+# Verify g-ir-scanner works before proceeding
+echo "Verifying g-ir-scanner..."
+if ! /opt/hud/bin/g-ir-scanner --version; then
+    echo "ERROR: g-ir-scanner not working!"
+    echo "Run gobject-introspection-1.84.0-rebuild.huddef first!"
+    exit 1
+fi
+echo "g-ir-scanner OK: $(/opt/hud/bin/g-ir-scanner --version)"
+
 mkdir -p build
 cd build
-meson setup --prefix=/opt/hud --buildtype=release -Dman-pages=disabled -Dtests=false ..
+
+meson setup ..                       \
+      --prefix=/opt/hud              \
+      --buildtype=release            \
+      -D introspection=enabled       \
+      -D man-pages=disabled          \
+      -D tests=false
+
 [build]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share"
+export GI_TYPELIB_PATH="/opt/hud/lib/girepository-1.0:/opt/hud/lib64/girepository-1.0"
+export GI_GIR_PATH="/opt/hud/share/gir-1.0"
 cd build
 ninja
+
 [install]
 cd build
 DESTDIR=$DESTDIR ninja install
+
 [postinst]
-echo "✓ glib 2.84.4 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig
+
+echo ""
+echo "═══════════════════════════════════════════════════════════"
+echo "  GLib 2.84.4 Stage 2 Complete (WITH introspection)"
+echo "═══════════════════════════════════════════════════════════"
+echo ""
+
+# Verify GIR files are installed
+if [ -f /opt/hud/share/gir-1.0/GLib-2.0.gir ]; then
+    echo "✓ GLib-2.0.gir installed"
+else
+    echo "⚠ GLib-2.0.gir NOT found"
+fi
+
+if [ -f /opt/hud/share/gir-1.0/GObject-2.0.gir ]; then
+    echo "✓ GObject-2.0.gir installed"
+else
+    echo "⚠ GObject-2.0.gir NOT found"
+fi
+
+if [ -f /opt/hud/share/gir-1.0/Gio-2.0.gir ]; then
+    echo "✓ Gio-2.0.gir installed"
+else
+    echo "⚠ Gio-2.0.gir NOT found"
+fi
+
+if [ -f /opt/hud/lib/girepository-1.0/GLib-2.0.typelib ]; then
+    echo "✓ GLib-2.0.typelib installed"
+else
+    echo "⚠ GLib-2.0.typelib NOT found"
+fi
+
+echo ""
+echo "GIR files location: /opt/hud/share/gir-1.0/"
+echo "Typelib location:   /opt/hud/lib/girepository-1.0/"
+echo ""
+echo "GLib 2.84.4 with introspection is ready for NetworkManager!"
+echo ""
```

</details>


### `glusterfs`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/g/glusterfs/glusterfs-11.1.huddef` | 11.1 | `a2ce9d35dcf0` | `61112e0ca135` | **POOL** |
| `sources/definitions/14 Feb 2026/glusterfs-11.1.huddef` | 11.1 | `a2ce9d35dcf0` | `61112e0ca135` | **= POOL** |
| `sources/definitions/old/packages/glusterfs-11.1.huddef` | 11.1 | `ccbaa9040ade` | `127f2b3c7450` | alt |
| `sources/definitions/old/updated-packages/glusterfs-11.1.huddef` | 11.1 | `ccbaa9040ade` | `127f2b3c7450` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/glusterfs-11.1.huddef</code> (16 added, 150 removed)</summary>

```diff
--- pool/main/g/glusterfs/glusterfs-11.1.huddef
+++ sources/definitions/old/packages/glusterfs-11.1.huddef
@@ -1,15 +1,4 @@
-# HUD Package Definition - GlusterFS 11.1
-# Distributed scalable network filesystem for cloud storage
-# Essential for: HA shared storage, VM live migration, storage replication
-# Reference: https://www.gluster.org/
-#
-# FIXES APPLIED:
-# - Replace broken config.sub/config.guess with system copies
-# - Explicit --build/--host triplets to avoid autoconf newline bug
-# - Disable io_uring (not available)
-# - TIRPC support via CFLAGS/LDFLAGS pointing to /opt/hud/include/tirpc
-# - Move mount.glusterfs from /sbin to /opt/hud/sbin to avoid wiping system /sbin
-# - Remove all non-/opt/hud system directories from package to prevent overwriting
-# - Symlinks for /sbin/mount.glusterfs created in postinst instead
+# HUD Package Definition - glusterfs 11.1
+# Auto-generated for oVirt infrastructure
 
 Package: glusterfs
@@ -17,150 +6,27 @@
 Architecture: x86_64
 Section: storage
-Depends: python3, liburcu, libxml2, openssl, libaio, readline, ncurses, libtirpc, sqlite
-Description: Distributed scalable network filesystem
+Depends: python3,glib2,openssl,libxml2,libaio,libuuid,fuse3,libibverbs,rdma-core
+Description: Distributed file system
 Source: https://download.gluster.org/pub/gluster/glusterfs/11/11.1/glusterfs-11.1.tar.gz
+Service: glusterd
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include -I/opt/hud/include/tirpc"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 -ltirpc"
-export PYTHON=/usr/bin/python3
-
-# Install Python dependencies
-pip3 install pyxattr --break-system-packages -q 2>/dev/null || true
-
-# Replace broken config.sub and config.guess
-for f in config.sub config.guess; do
-    if [ -f /usr/share/automake-*/$f ]; then
-        cp /usr/share/automake-*/$f ./$f
-    elif [ -f /usr/share/libtool/build-aux/$f ]; then
-        cp /usr/share/libtool/build-aux/$f ./$f
-    fi
-    find . -name "$f" -exec cp ./$f {} \; 2>/dev/null || true
-done
-chmod +x config.sub config.guess
-
-./configure --prefix=/opt/hud \
-            --build=x86_64-unknown-linux-gnu \
-            --host=x86_64-unknown-linux-gnu \
-            --sysconfdir=/etc \
-            --localstatedir=/var \
-            --libdir=/opt/hud/lib64 \
-            --with-pkgconfigdir=/opt/hud/lib64/pkgconfig \
-            --enable-gnfs \
-            --disable-crypt-xlator \
-            --disable-georeplication \
-            --disable-linux-io_uring \
-            --with-libtirpc
+./configure --prefix=/opt/hud --sysconfdir=/opt/hud/etc --localstatedir=/opt/hud/var
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-
-make -j$(nproc)
+make
 
 [install]
 make DESTDIR=$DESTDIR install
 
-# CRITICAL: Move mount.glusterfs out of /sbin into /opt/hud/sbin
-# This prevents the .hud package from containing /sbin/ which would
-# overwrite the system /sbin directory when extracted via tar
-mkdir -p $DESTDIR/opt/hud/sbin
-mv $DESTDIR/sbin/mount.glusterfs $DESTDIR/opt/hud/sbin/mount.glusterfs 2>/dev/null || true
+[postinst]
+ldconfig 2>/dev/null || true
+echo "glusterfs 11.1 installed to /opt/hud"
 
-# Remove ALL system directories from the package root
-# Only /opt/hud and /etc and /var should remain
-rm -rf $DESTDIR/sbin 2>/dev/null || true
-rm -rf $DESTDIR/bin 2>/dev/null || true
-rm -rf $DESTDIR/usr 2>/dev/null || true
-rm -rf $DESTDIR/lib 2>/dev/null || true
-rm -rf $DESTDIR/lib64 2>/dev/null || true
+[prerm]
+# Stop service if running
+systemctl stop hud-glusterd 2>/dev/null || true
+systemctl disable hud-glusterd 2>/dev/null || true
 
-# Install Python API
-cd extras/hook-scripts
-cp -a * $DESTDIR/opt/hud/share/glusterfs/scripts/ 2>/dev/null || true
-
-[postinst]
-# Add library paths
-echo "/opt/hud/lib64" > /etc/ld.so.conf.d/glusterfs.conf
-echo "/opt/hud/lib64/glusterfs" >> /etc/ld.so.conf.d/glusterfs.conf
-ldconfig
-
-# Create mount helper symlink (safe - only adds one file)
-ln -sf /opt/hud/sbin/mount.glusterfs /sbin/mount.glusterfs
-
-# Create gluster user and group
-groupadd -r gluster 2>/dev/null || true
-useradd -r -g gluster -d /var/lib/glusterd -s /sbin/nologin \
-    -c "GlusterFS user" gluster 2>/dev/null || true
-
-# Create directories
-mkdir -p /var/lib/glusterd
-mkdir -p /var/log/glusterfs
-mkdir -p /var/run/gluster
-mkdir -p /etc/glusterfs
-
-# Set ownership
-chown -R gluster:gluster /var/lib/glusterd
-chown -R gluster:gluster /var/log/glusterfs
-chown -R gluster:gluster /var/run/gluster
-
-# Create systemd service for glusterd
-cat > /etc/systemd/system/glusterd.service << 'EOFSVC'
-[Unit]
-Description=GlusterFS Management Daemon
-Requires=network.target
-After=network.target
-
-[Service]
-Type=forking
-PIDFile=/var/run/glusterd.pid
-ExecStart=/opt/hud/sbin/glusterd -p /var/run/glusterd.pid
-ExecReload=/bin/kill -HUP $MAINPID
-KillMode=process
-Restart=on-failure
-RestartSec=10
-LimitNOFILE=65536
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Create firewalld service definition
-mkdir -p /etc/firewalld/services
-cat > /etc/firewalld/services/glusterfs.xml << 'EOFXML'
-<?xml version="1.0" encoding="utf-8"?>
-<service>
-  <short>GlusterFS</short>
-  <description>GlusterFS is a scalable network filesystem</description>
-  <port protocol="tcp" port="24007-24008"/>
-  <port protocol="tcp" port="49152-49251"/>
-</service>
-EOFXML
-
-# Enable and start service
-systemctl daemon-reload
-systemctl enable glusterd.service
-systemctl start glusterd.service || true
-
-# Add firewall rules if firewalld is running
-if systemctl is-active --quiet firewalld; then
-    firewall-cmd --permanent --add-service=glusterfs 2>/dev/null || true
-    firewall-cmd --reload 2>/dev/null || true
-fi
-
-echo ""
-echo "============================================"
-echo "GlusterFS 11.1 installed successfully"
-echo "============================================"
-echo ""
-echo "Service: systemctl status glusterd"
-echo "Commands:"
-echo "  gluster peer status"
-echo "  gluster volume list"
-echo "  gluster volume info"
-echo ""
-echo "Firewall ports opened: 24007-24008, 49152-49251"
-echo ""
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `gnutls`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/g/gnutls/gnutls-3.8.10.huddef` | 3.8.10 | `eb657dd32ae8` | `bee401a05d03` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/gnutls-3.8.10.huddef` | 3.8.10 | `f872937cde88` | `1aeb521dd047` | alt |
| `sources/definitions/old/packages/gnutls-3.8.10.huddef` | 3.8.10 | `46515e000a23` | `73353f15c7c9` | alt |
| `sources/definitions/old/updated-packages/gnutls-3.8.10.huddef` | 3.8.10 | `eb657dd32ae8` | `bee401a05d03` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/gnutls-3.8.10.huddef</code> (11 added, 22 removed)</summary>

```diff
--- pool/main/g/gnutls/gnutls-3.8.10.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/gnutls-3.8.10.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - gnutls 3.8.10
-# Based on BLFS 12.4 documentation
+# HUD Package Definition - GnuTLS 3.8.10
+# Transport Layer Security Library
+# Secure communications library implementing TLS/SSL protocols
 
 Package: gnutls
@@ -6,36 +7,24 @@
 Architecture: x86_64
 Section: security
-Depends: nettle,libtasn1,libunistring,p11-kit
-Description: GnuTLS - secure communications library implementing TLS, SSL, and DTLS protocols
+Depends: nettle, libunistring, libtasn1, p11-kit
+Description: Library implementing TLS 1.3, 1.2, 1.1, 1.0 protocols for secure communications
 Source: https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.10.tar.xz
 
 [configure]
-# Set up environment so configure finds /opt/hud dependencies FIRST
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 -Wl,-rpath,/opt/hud/lib"
-export CPPFLAGS="-I/opt/hud/include"
-export CFLAGS="-I/opt/hud/include"
-export PATH="/opt/hud/bin:$PATH"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64"
+# Set pkg-config path for dependencies
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 
 ./configure --prefix=/opt/hud \
             --docdir=/opt/hud/share/doc/gnutls-3.8.10 \
-            --disable-static \
-            --with-default-trust-store-pkcs11="pkcs11:"
+            --with-default-trust-store-pkcs11="pkcs11:" \
+            --disable-static
 
 [build]
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64"
 make -j$(nproc)
 
 [install]
-make install DESTDIR=$DESTDIR
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "gnutls 3.8.10 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ GnuTLS 3.8.10 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/gnutls-3.8.10.huddef</code> (7 added, 19 removed)</summary>

```diff
--- pool/main/g/gnutls/gnutls-3.8.10.huddef
+++ sources/definitions/old/packages/gnutls-3.8.10.huddef
@@ -1,33 +1,21 @@
 # HUD Package Definition - gnutls 3.8.10
-# Based on BLFS 12.4 documentation
+# Auto-generated for oVirt infrastructure
 
 Package: gnutls
 Version: 3.8.10
 Architecture: x86_64
-Section: security
-Depends: nettle,libtasn1,libunistring,p11-kit
-Description: GnuTLS - secure communications library implementing TLS, SSL, and DTLS protocols
+Section: misc
+Depends: tl-installer,libunistring,valgrind,libtasn1,libidn2,make-ca,net-tools,p11-kit,brotli,gtk-doc,texlive,nettle
+Description: GnuTLS-3.8.10
 Source: https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.10.tar.xz
 
 [configure]
-# Set up environment so configure finds /opt/hud dependencies FIRST
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 -Wl,-rpath,/opt/hud/lib"
-export CPPFLAGS="-I/opt/hud/include"
-export CFLAGS="-I/opt/hud/include"
-export PATH="/opt/hud/bin:$PATH"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64"
-
-./configure --prefix=/opt/hud \
-            --docdir=/opt/hud/share/doc/gnutls-3.8.10 \
-            --disable-static \
-            --with-default-trust-store-pkcs11="pkcs11:"
+./configure --prefix=/opt/hud
 
 [build]
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64"
 make -j$(nproc)
 
 [install]
-make install DESTDIR=$DESTDIR
+make install
 
 [postinst]
@@ -36,5 +24,5 @@
 
 [prerm]
-# No services to stop
+# Stop service if running
 
 [postrm]
```

</details>


### `harfbuzz`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/h/harfbuzz/harfbuzz-11.4.1.huddef` | 11.4.1 | `d03327b6a761` | `6f6bd042e776` | **POOL** |
| `sources/definitions/old/0/harfbuzz-11.4.1.huddef` | 11.4.1 | `3d04034c215b` | `cbc097669135` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/harfbuzz-11.4.1.huddef` | 11.4.1 | `f8a41fad0843` | `63a14b7d736d` | alt |
| `sources/definitions/old/packages/harfbuzz-11.4.1.huddef` | 11.4.1 | `d03327b6a761` | `6f6bd042e776` | **= POOL** |
| `sources/definitions/old/updated-packages/harfbuzz-11.4.1.huddef` | 11.4.1 | `d03327b6a761` | `6f6bd042e776` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/harfbuzz-11.4.1.huddef</code> (13 added, 20 removed)</summary>

```diff
--- pool/main/h/harfbuzz/harfbuzz-11.4.1.huddef
+++ sources/definitions/old/0/harfbuzz-11.4.1.huddef
@@ -1,29 +1,22 @@
 # HUD Package Definition - harfbuzz 11.4.1
-# Auto-generated for oVirt infrastructure
-
+# OpenType text shaping engine
 Package: harfbuzz
 Version: 11.4.1
 Architecture: x86_64
-Section: misc
-Depends: graphite2,libreoffice,git,glib2,icu,texlive,gtk-doc,cairo
-Description: harfBuzz-11.4.1
+Section: graphics
+Depends: glib,freetype,icu,graphite2
+Description: OpenType text shaping engine
 Source: https://github.com/harfbuzz/harfbuzz/releases/download/11.4.1/harfbuzz-11.4.1.tar.xz
-
 [configure]
-./configure --prefix=/opt/hud
-
+mkdir -p build
+cd build
+meson setup .. --prefix=/opt/hud --buildtype=release -D graphite2=enabled
 [build]
-make -j$(nproc)
-
+cd build
+ninja
 [install]
-make install
-
+cd build
+DESTDIR=$DESTDIR ninja install
 [postinst]
-ldconfig 2>/dev/null || true
-echo "harfbuzz 11.4.1 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ harfbuzz 11.4.1 installed to /opt/hud"
+/sbin/ldconfig
```

</details>

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/harfbuzz-11.4.1.huddef</code> (22 added, 15 removed)</summary>

```diff
--- pool/main/h/harfbuzz/harfbuzz-11.4.1.huddef
+++ sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/harfbuzz-11.4.1.huddef
@@ -1,29 +1,36 @@
-# HUD Package Definition - harfbuzz 11.4.1
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - HarfBuzz 11.4.1
+# Text Shaping Engine
+# OpenType text shaping engine
 
 Package: harfbuzz
 Version: 11.4.1
 Architecture: x86_64
-Section: misc
-Depends: graphite2,libreoffice,git,glib2,icu,texlive,gtk-doc,cairo
-Description: harfBuzz-11.4.1
+Section: graphics
+Depends: glib, freetype, icu
+Description: OpenType text shaping engine for complex text layout
 Source: https://github.com/harfbuzz/harfbuzz/releases/download/11.4.1/harfbuzz-11.4.1.tar.xz
 
 [configure]
-./configure --prefix=/opt/hud
+mkdir -p build
+cd build
+
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+
+meson setup ..              \
+    --prefix=/opt/hud       \
+    --buildtype=release     \
+    -D graphite2=disabled   \
+    -D tests=disabled       \
+    -D docs=disabled
 
 [build]
-make -j$(nproc)
+cd build
+ninja
 
 [install]
-make install
+cd build
+DESTDIR=$DESTDIR ninja install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "harfbuzz 11.4.1 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ HarfBuzz 11.4.1 installed to /opt/hud"
```

</details>


### `icu`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/i/icu/icu-77.1.huddef` | 77.1 | `c1f5fcf93dac` | `fb0382eb8656` | **POOL** |
| `sources/definitions/old/0/icu-77.1.huddef` | 77.1 | `bc85ffb40acc` | `4679833f8889` | alt |
| `sources/definitions/old/packages/icu-77.1.huddef` | 77.1 | `f55ed3554a25` | `9e5931d331ea` | alt |
| `sources/definitions/old/updated-packages/icu-77.1.huddef` | 77.1 | `c1f5fcf93dac` | `fb0382eb8656` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/icu-77.1.huddef</code> (3 added, 7 removed)</summary>

```diff
--- pool/main/i/icu/icu-77.1.huddef
+++ sources/definitions/old/0/icu-77.1.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - icu 77.1
-# International Components for Unicode (ICU)
+# International Components for Unicode
 Package: icu
 Version: 77.1
@@ -6,5 +6,5 @@
 Section: libraries
 Depends:
-Description: International Components for Unicode - C/C++ libraries providing Unicode and Globalization support
+Description: International Components for Unicode libraries
 Source: https://github.com/unicode-org/icu/releases/download/release-77-1/icu4c-77_1-src.tgz
 [configure]
@@ -18,8 +18,4 @@
 make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ icu 77.1 installed to /opt/hud"
-[prerm]
-# Stop service if running
-[postrm]
-ldconfig 2>/dev/null || true
+/sbin/ldconfig
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/icu-77.1.huddef</code> (15 added, 11 removed)</summary>

```diff
--- pool/main/i/icu/icu-77.1.huddef
+++ sources/definitions/old/packages/icu-77.1.huddef
@@ -1,25 +1,29 @@
 # HUD Package Definition - icu 77.1
-# International Components for Unicode (ICU)
+# Auto-generated for oVirt infrastructure
+
 Package: icu
 Version: 77.1
 Architecture: x86_64
-Section: libraries
-Depends:
-Description: International Components for Unicode - C/C++ libraries providing Unicode and Globalization support
-Source: https://github.com/unicode-org/icu/releases/download/release-77-1/icu4c-77_1-src.tgz
+Section: misc
+Depends: 
+Description: icu-77.1
+Source: 
+
 [configure]
-cd source
 ./configure --prefix=/opt/hud
+
 [build]
-cd source
-make
+make -j$(nproc)
+
 [install]
-cd source
-make DESTDIR=$DESTDIR install
+make install
+
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ icu 77.1 installed to /opt/hud"
+echo "icu 77.1 installed to /opt/hud"
+
 [prerm]
 # Stop service if running
+
 [postrm]
 ldconfig 2>/dev/null || true
```

</details>


### `iptables`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/i/iptables/iptables-1.8.11.huddef` | 1.8.11 | `ec61860a7f03` | `b8c678c67c26` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/iptables-1.8.11.huddef` | 1.8.11 | `ec61860a7f03` | `b8c678c67c26` | **= POOL** |
| `sources/definitions/old/packages/iptables-1.8.11.huddef` | 1.8.11 | `7c8170e34af1` | `5ccc292813ae` | alt |
| `sources/definitions/old/updated-packages/iptables-1.8.11.huddef` | 1.8.11 | `7c8170e34af1` | `5ccc292813ae` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/iptables-1.8.11.huddef</code> (16 added, 25 removed)</summary>

```diff
--- pool/main/i/iptables/iptables-1.8.11.huddef
+++ sources/definitions/old/packages/iptables-1.8.11.huddef
@@ -1,42 +1,33 @@
 # HUD Package Definition - iptables 1.8.11
-# Linux kernel packet filtering ruleset tool
-# Recommended by NetworkManager for firewall integration
+# Packet filtering framework
 
 Package: iptables
 Version: 1.8.11
 Architecture: x86_64
-Section: networking
-Depends:
-Description: Userspace command line program for kernel packet filtering
+Section: network
+Depends: libmnl,libnftnl
+Description: Linux kernel packet filtering framework
 Source: https://www.netfilter.org/projects/iptables/files/iptables-1.8.11.tar.xz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-./configure --prefix=/opt/hud \
-            --disable-nftables \
-            --enable-libipq
+./configure \
+    --prefix=/opt/hud \
+    --sysconfdir=/opt/hud/etc \
+    --enable-libipq \
+    --with-xtlibdir=/opt/hud/lib/xtables \
+    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
+    CPPFLAGS="-I/opt/hud/include"
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make -j$(nproc)
 
 [install]
 make DESTDIR=$DESTDIR install
+# Create symlinks for legacy commands
+for cmd in iptables iptables-save iptables-restore ip6tables ip6tables-save ip6tables-restore; do
+    ln -sf xtables-nft-multi $DESTDIR/opt/hud/sbin/$cmd 2>/dev/null || true
+done
 
 [postinst]
-ldconfig
-# Create symlinks for system integration
-if [ ! -e /sbin/iptables ]; then
-    ln -sf /opt/hud/sbin/iptables /sbin/iptables 2>/dev/null || true
-fi
-if [ ! -e /sbin/ip6tables ]; then
-    ln -sf /opt/hud/sbin/ip6tables /sbin/ip6tables 2>/dev/null || true
-fi
+ldconfig 2>/dev/null || true
 echo "✓ iptables 1.8.11 installed to /opt/hud"
-echo "  Note: Configure kernel with CONFIG_NETFILTER for packet filtering"
```

</details>


### `json-c`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/j/json-c/json-c-0.18.huddef` | 0.18 | `4e80a800a4ff` | `96410ef29b29` | **POOL** |
| `sources/definitions/libvirt/json-c-0.18.huddef` | 0.18 | `4e80a800a4ff` | `96410ef29b29` | **= POOL** |
| `sources/definitions/old/0/json-c-0.18.huddef` | 0.18 | `ff9a83f177e5` | `b36b56e2207d` | alt |

<details><summary>diff → <code>sources/definitions/old/0/json-c-0.18.huddef</code> (7 added, 27 removed)</summary>

```diff
--- pool/main/j/json-c/json-c-0.18.huddef
+++ sources/definitions/old/0/json-c-0.18.huddef
@@ -1,42 +1,22 @@
 # HUD Package Definition - json-c 0.18
-# JSON parsing library for C
-# Required by libvirt for QEMU driver
-
+# JSON C library
 Package: json-c
 Version: 0.18
 Architecture: x86_64
 Section: libraries
-Depends:
-Description: JSON parsing library for C
+Depends: cmake
+Description: JSON implementation in C
 Source: https://s3.amazonaws.com/json-c_releases/releases/json-c-0.18.tar.gz
-
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
 mkdir -p build
 cd build
-cmake ..                                \
-      -DCMAKE_INSTALL_PREFIX=/opt/hud   \
-      -DCMAKE_BUILD_TYPE=Release        \
-      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-      -DBUILD_SHARED_LIBS=ON            \
-      -DBUILD_STATIC_LIBS=OFF           \
-      -DBUILD_APPS=OFF                  \
-      -DENABLE_THREADING=ON
-
+cmake -DCMAKE_INSTALL_PREFIX=/opt/hud -DCMAKE_BUILD_TYPE=Release -DBUILD_STATIC_LIBS=OFF ..
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 cd build
 make
-
 [install]
 cd build
-DESTDIR=$DESTDIR make install
-
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig
-echo "json-c 0.18 installed"
+echo "✓ json-c 0.18 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `json-glib`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/j/json-glib/json-glib-1.10.6.huddef` | 1.10.6 | `c71cf453f7a1` | `db0284085ea9` | **POOL** |
| `sources/definitions/14 Feb 2026/json-glib-1.10.6.huddef` | 1.10.6 | `c71cf453f7a1` | `db0284085ea9` | **= POOL** |
| `sources/definitions/old/packages/json-glib-1.10.6.huddef` | 1.10.6 | `e9c7326c5fae` | `16d28486cccc` | alt |
| `sources/definitions/old/updated-packages/json-glib-1.10.6.huddef` | 1.10.6 | `5115ea60c364` | `68c2fa8c7905` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/json-glib-1.10.6.huddef</code> (13 added, 8 removed)</summary>

```diff
--- pool/main/j/json-glib/json-glib-1.10.6.huddef
+++ sources/definitions/old/packages/json-glib-1.10.6.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - json-glib 1.10.6
-# JSON library for GLib
+# Auto-generated for oVirt infrastructure
 
 Package: json-glib
@@ -6,19 +6,24 @@
 Architecture: x86_64
 Section: libraries
-Depends: glib
-Description: Library providing serialization and deserialization support for JSON format
+Depends: glib2,gobject-introspection
+Description: JSON library for GLib
 Source: https://download.gnome.org/sources/json-glib/1.10/json-glib-1.10.6.tar.xz
-MD5sum: d4bf13ddd1e6d607d039d39286f9e3d0
 
 [configure]
-mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release -Ddocumentation=disabled -Dintrospection=disabled -Dtests=false ..
+meson setup build --prefix=/opt/hud
 
 [build]
-cd build && ninja -j$(nproc)
+ninja -C build
 
 [install]
-cd build && DESTDIR=$DESTDIR ninja install
+DESTDIR=$DESTDIR ninja -C build install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ json-glib 1.10.6 installed to /opt/hud"
+echo "json-glib 1.10.6 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/updated-packages/json-glib-1.10.6.huddef</code> (2 added, 2 removed)</summary>

```diff
--- pool/main/j/json-glib/json-glib-1.10.6.huddef
+++ sources/definitions/old/updated-packages/json-glib-1.10.6.huddef
@@ -6,5 +6,5 @@
 Architecture: x86_64
 Section: libraries
-Depends: glib
+Depends: glib2
 Description: Library providing serialization and deserialization support for JSON format
 Source: https://download.gnome.org/sources/json-glib/1.10/json-glib-1.10.6.tar.xz
@@ -12,5 +12,5 @@
 
 [configure]
-mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release -Ddocumentation=disabled -Dintrospection=disabled -Dtests=false ..
+mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release ..
 
 [build]
```

</details>


### `libICE`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libICE/libICE-1.1.2.huddef` | 1.1.2 | `92bc75b32b3d` | `8f185a542031` | **POOL** |
| `sources/definitions/old/0/libICE-1.1.2.huddef` | 1.1.2 | `d72fd6f9d3e1` | `a5abd2cf046d` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libICE-1.1.2.huddef` | 1.1.2 | `92bc75b32b3d` | `8f185a542031` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libICE-1.1.2.huddef</code> (6 added, 15 removed)</summary>

```diff
--- pool/main/l/libICE/libICE-1.1.2.huddef
+++ sources/definitions/old/0/libICE-1.1.2.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libICE 1.1.2
-# X Inter-Client Exchange Library
-# X11 Inter-Client Exchange library
-
+# X Inter Client Exchange Library
 Package: libICE
 Version: 1.1.2
 Architecture: x86_64
 Section: xorg
-Depends: xorgproto, xtrans, util-macros
-Description: X11 Inter-Client Exchange library
+Depends: xorgproto,xtrans
+Description: X Inter Client Exchange Library
 Source: https://www.x.org/pub/individual/lib/libICE-1.1.2.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libICE 1.1.2 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libSM`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libSM/libSM-1.2.6.huddef` | 1.2.6 | `e414b3535208` | `20b45d895f7f` | **POOL** |
| `sources/definitions/old/0/libSM-1.2.6.huddef` | 1.2.6 | `f6f4927c7512` | `43bfbfa3bfc0` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libSM-1.2.6.huddef` | 1.2.6 | `e414b3535208` | `20b45d895f7f` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libSM-1.2.6.huddef</code> (5 added, 14 removed)</summary>

```diff
--- pool/main/l/libSM/libSM-1.2.6.huddef
+++ sources/definitions/old/0/libSM-1.2.6.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libSM 1.2.6
 # X Session Management Library
-# X11 Session Management library
-
 Package: libSM
 Version: 1.2.6
 Architecture: x86_64
 Section: xorg
-Depends: libICE, xorgproto, xtrans, util-macros
-Description: X11 Session Management library
+Depends: libICE
+Description: X Session Management Library
 Source: https://www.x.org/pub/individual/lib/libSM-1.2.6.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libSM 1.2.6 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libX11`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libX11/libX11-1.8.12.huddef` | 1.8.12 | `eecc8aa1f6c5` | `5793c2d429cc` | **POOL** |
| `sources/definitions/old/0/libX11-1.8.12.huddef` | 1.8.12 | `4f826ab97a8b` | `e96053439c95` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libX11-1.8.12.huddef` | 1.8.12 | `eecc8aa1f6c5` | `5793c2d429cc` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libX11-1.8.12.huddef</code> (6 added, 23 removed)</summary>

```diff
--- pool/main/l/libX11/libX11-1.8.12.huddef
+++ sources/definitions/old/0/libX11-1.8.12.huddef
@@ -1,35 +1,18 @@
 # HUD Package Definition - libX11 1.8.12
-# X11 Client Library
-# Main client library for X Window System
-
+# Xlib library
 Package: libX11
 Version: 1.8.12
 Architecture: x86_64
 Section: xorg
-Depends: libxcb, xtrans, xorgproto, util-macros
-Description: Main X11 client library for X Window System applications
+Depends: libxcb,xtrans,xorgproto
+Description: Xlib - C Language X Interface library
 Source: https://www.x.org/pub/individual/lib/libX11-1.8.12.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud    \
-            --sysconfdir=/etc    \
-            --localstatedir=/var \
-            --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
-
-# Create symlinks for compatibility
-ln -sfv /opt/hud/lib/X11 /usr/lib/X11 2>/dev/null || true
-ln -sfv /opt/hud/include/X11 /usr/include/X11 2>/dev/null || true
-
 echo "✓ libX11 1.8.12 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXau`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXau/libXau-1.0.12.huddef` | 1.0.12 | `cbc9a028e700` | `5619966fcff1` | **POOL** |
| `sources/definitions/old/0/libXau-1.0.12.huddef` | 1.0.12 | `6e045797e674` | `6012fbf74117` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXau-1.0.12.huddef` | 1.0.12 | `cbc9a028e700` | `5619966fcff1` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXau-1.0.12.huddef</code> (6 added, 17 removed)</summary>

```diff
--- pool/main/l/libXau/libXau-1.0.12.huddef
+++ sources/definitions/old/0/libXau-1.0.12.huddef
@@ -1,29 +1,18 @@
 # HUD Package Definition - libXau 1.0.12
-# X Authorization Library
-# X Window authorization protocol library
-# Fixed: Added util-macros dependency and proper PKG_CONFIG_PATH
-
+# X11 Authorization Protocol library
 Package: libXau
 Version: 1.0.12
 Architecture: x86_64
 Section: xorg
-Depends: xorgproto, util-macros
-Description: X Window System authorization protocol library
+Depends: xorgproto
+Description: Library implementing the X11 Authorization Protocol
 Source: https://www.x.org/pub/individual/lib/libXau-1.0.12.tar.xz
-
 [configure]
-# Ensure pkg-config can find xorgproto and util-macros
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXau 1.0.12 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXdmcp`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXdmcp/libXdmcp-1.1.5.huddef` | 1.1.5 | `2db5154c85fa` | `58fd29f297bf` | **POOL** |
| `sources/definitions/old/0/libXdmcp-1.1.5.huddef` | 1.1.5 | `8849ab2becf5` | `38b55544e8be` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXdmcp-1.1.5.huddef` | 1.1.5 | `2db5154c85fa` | `58fd29f297bf` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXdmcp-1.1.5.huddef</code> (5 added, 16 removed)</summary>

```diff
--- pool/main/l/libXdmcp/libXdmcp-1.1.5.huddef
+++ sources/definitions/old/0/libXdmcp-1.1.5.huddef
@@ -1,29 +1,18 @@
 # HUD Package Definition - libXdmcp 1.1.5
-# X Display Manager Control Protocol Library
-# XDMCP protocol library
-# Fixed: Added util-macros dependency and proper PKG_CONFIG_PATH
-
+# X Display Manager Control Protocol library
 Package: libXdmcp
 Version: 1.1.5
 Architecture: x86_64
 Section: xorg
-Depends: xorgproto, util-macros
+Depends: xorgproto
 Description: X Display Manager Control Protocol library
 Source: https://www.x.org/pub/individual/lib/libXdmcp-1.1.5.tar.xz
-
 [configure]
-# Ensure pkg-config can find xorgproto and util-macros
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXdmcp 1.1.5 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXext`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXext/libXext-1.3.6.huddef` | 1.3.6 | `6630d33542e1` | `2b18d21175de` | **POOL** |
| `sources/definitions/old/0/libXext-1.3.6.huddef` | 1.3.6 | `4d80a98fb16b` | `1c721e4bd9a0` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXext-1.3.6.huddef` | 1.3.6 | `6630d33542e1` | `2b18d21175de` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXext-1.3.6.huddef</code> (6 added, 15 removed)</summary>

```diff
--- pool/main/l/libXext/libXext-1.3.6.huddef
+++ sources/definitions/old/0/libXext-1.3.6.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libXext 1.3.6
-# X11 Extension Library
-# X11 miscellaneous extension library
-
+# Misc X Extension Library
 Package: libXext
 Version: 1.3.6
 Architecture: x86_64
 Section: xorg
-Depends: libX11, xorgproto, util-macros
-Description: X11 miscellaneous extension library
+Depends: libX11
+Description: Misc X Extension Library
 Source: https://www.x.org/pub/individual/lib/libXext-1.3.6.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXext 1.3.6 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXfixes`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXfixes/libXfixes-6.0.1.huddef` | 6.0.1 | `ca0edff606e0` | `ee5a04b0d030` | **POOL** |
| `sources/definitions/old/0/libXfixes-6.0.1.huddef` | 6.0.1 | `dc507651a9f6` | `175c7f18ffbe` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXfixes-6.0.1.huddef` | 6.0.1 | `ca0edff606e0` | `ee5a04b0d030` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXfixes-6.0.1.huddef</code> (5 added, 14 removed)</summary>

```diff
--- pool/main/l/libXfixes/libXfixes-6.0.1.huddef
+++ sources/definitions/old/0/libXfixes-6.0.1.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libXfixes 6.0.1
 # X Fixes Extension Library
-# X11 Fixes extension library
-
 Package: libXfixes
 Version: 6.0.1
 Architecture: x86_64
 Section: xorg
-Depends: libX11, xorgproto, util-macros
-Description: X11 Fixes extension library
+Depends: libX11
+Description: X Fixes Extension Library providing augmented protocol requests
 Source: https://www.x.org/pub/individual/lib/libXfixes-6.0.1.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXfixes 6.0.1 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXi`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXi/libXi-1.8.2.huddef` | 1.8.2 | `20dde16d6aa5` | `85f9f3b122ec` | **POOL** |
| `sources/definitions/old/0/libXi-1.8.2.huddef` | 1.8.2 | `6b63f4eee3de` | `933a2770cbae` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXi-1.8.2.huddef` | 1.8.2 | `20dde16d6aa5` | `85f9f3b122ec` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXi-1.8.2.huddef</code> (5 added, 14 removed)</summary>

```diff
--- pool/main/l/libXi/libXi-1.8.2.huddef
+++ sources/definitions/old/0/libXi-1.8.2.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libXi 1.8.2
 # X Input Extension Library
-# X11 Input extension library
-
 Package: libXi
 Version: 1.8.2
 Architecture: x86_64
 Section: xorg
-Depends: libX11, libXext, libXfixes, xorgproto, util-macros
-Description: X11 Input extension library
+Depends: libXext,libXfixes
+Description: X Input Extension Library
 Source: https://www.x.org/pub/individual/lib/libXi-1.8.2.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXi 1.8.2 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXrandr`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXrandr/libXrandr-1.5.4.huddef` | 1.5.4 | `0afe9b9b3baf` | `3fe2bf283b2e` | **POOL** |
| `sources/definitions/old/0/libXrandr-1.5.4.huddef` | 1.5.4 | `bfb57c89eef2` | `e85f03f14b65` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXrandr-1.5.4.huddef` | 1.5.4 | `0afe9b9b3baf` | `3fe2bf283b2e` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXrandr-1.5.4.huddef</code> (5 added, 14 removed)</summary>

```diff
--- pool/main/l/libXrandr/libXrandr-1.5.4.huddef
+++ sources/definitions/old/0/libXrandr-1.5.4.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libXrandr 1.5.4
-# X Resize and Rotate Extension Library
-# X11 RandR extension library
-
+# X Resize, Rotate and Reflection extension library
 Package: libXrandr
 Version: 1.5.4
 Architecture: x86_64
 Section: xorg
-Depends: libX11, libXext, libXrender, xorgproto, util-macros
+Depends: libXext,libXrender
 Description: X Resize, Rotate and Reflection extension library
 Source: https://www.x.org/pub/individual/lib/libXrandr-1.5.4.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXrandr 1.5.4 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXrender`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXrender/libXrender-0.9.12.huddef` | 0.9.12 | `5c8e579bdf82` | `ba1791d0c6b1` | **POOL** |
| `sources/definitions/old/0/libXrender-0.9.12.huddef` | 0.9.12 | `1faac7459221` | `fd82a0e701f8` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXrender-0.9.12.huddef` | 0.9.12 | `5c8e579bdf82` | `ba1791d0c6b1` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXrender-0.9.12.huddef</code> (5 added, 14 removed)</summary>

```diff
--- pool/main/l/libXrender/libXrender-0.9.12.huddef
+++ sources/definitions/old/0/libXrender-0.9.12.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libXrender 0.9.12
 # X Render Extension Library
-# X Rendering Extension client library
-
 Package: libXrender
 Version: 0.9.12
 Architecture: x86_64
 Section: xorg
-Depends: libX11, xorgproto, util-macros
-Description: X Rendering Extension client library
+Depends: libX11
+Description: X Render Extension Library
 Source: https://www.x.org/pub/individual/lib/libXrender-0.9.12.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXrender 0.9.12 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXt`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXt/libXt-1.3.1.huddef` | 1.3.1 | `da073f9db9af` | `3f1d4ed62198` | **POOL** |
| `sources/definitions/old/0/libXt-1.3.1.huddef` | 1.3.1 | `8ec50cfcb3b3` | `53ec26a1d955` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXt-1.3.1.huddef` | 1.3.1 | `da073f9db9af` | `3f1d4ed62198` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXt-1.3.1.huddef</code> (5 added, 16 removed)</summary>

```diff
--- pool/main/l/libXt/libXt-1.3.1.huddef
+++ sources/definitions/old/0/libXt-1.3.1.huddef
@@ -1,29 +1,18 @@
 # HUD Package Definition - libXt 1.3.1
 # X Toolkit Library
-# X Toolkit Intrinsics library
-
 Package: libXt
 Version: 1.3.1
 Architecture: x86_64
 Section: xorg
-Depends: libX11, libSM, libICE, xorgproto, util-macros
-Description: X Toolkit Intrinsics library
+Depends: libX11,libSM,libICE
+Description: X Toolkit Intrinsics Library
 Source: https://www.x.org/pub/individual/lib/libXt-1.3.1.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud                        \
-            --disable-static                         \
-            --with-appdefaultdir=/etc/X11/app-defaults
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static --with-appdefaultdir=/etc/X11/app-defaults
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXt 1.3.1 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libXtst`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libXtst/libXtst-1.2.5.huddef` | 1.2.5 | `af36b5468639` | `c3114390f4bb` | **POOL** |
| `sources/definitions/old/0/libXtst-1.2.5.huddef` | 1.2.5 | `0920bf49ddf1` | `f644cc407297` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libXtst-1.2.5.huddef` | 1.2.5 | `af36b5468639` | `c3114390f4bb` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libXtst-1.2.5.huddef</code> (6 added, 15 removed)</summary>

```diff
--- pool/main/l/libXtst/libXtst-1.2.5.huddef
+++ sources/definitions/old/0/libXtst-1.2.5.huddef
@@ -1,27 +1,18 @@
 # HUD Package Definition - libXtst 1.2.5
-# X Test Extension Library
-# X11 Testing -- Record extension library
-
+# Xtst Library
 Package: libXtst
 Version: 1.2.5
 Architecture: x86_64
 Section: xorg
-Depends: libX11, libXext, libXi, xorgproto, util-macros
-Description: X11 Testing -- Record extension library
+Depends: libXext,libXi
+Description: X Test extension library
 Source: https://www.x.org/pub/individual/lib/libXtst-1.2.5.tar.xz
-
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud --disable-static
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libXtst 1.2.5 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libaio`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libaio/libaio-0.3.113.huddef` | 0.3.113 | `492e0f788e72` | `2f5f6ec6e6f5` | **POOL** |
| `sources/definitions/old/packages/libaio-0.3.113.huddef` | 0.3.113 | `229deefce9e3` | `66582204c8d2` | alt |
| `sources/definitions/old/updated-packages/libaio-0.3.113.huddef` | 0.3.113 | `492e0f788e72` | `2f5f6ec6e6f5` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libaio-0.3.113.huddef</code> (13 added, 8 removed)</summary>

```diff
--- pool/main/l/libaio/libaio-0.3.113.huddef
+++ sources/definitions/old/packages/libaio-0.3.113.huddef
@@ -1,5 +1,4 @@
 # HUD Package Definition - libaio 0.3.113
-# Linux-native asynchronous I/O library
-# Note: libaio uses plain Makefile, no configure script
+# Auto-generated for oVirt infrastructure
 
 Package: libaio
@@ -7,18 +6,24 @@
 Architecture: x86_64
 Section: libraries
-Depends:
-Description: Linux-native asynchronous I/O access library
+Depends: 
+Description: Linux-native asynchronous I/O
 Source: https://pagure.io/libaio/archive/libaio-0.3.113/libaio-libaio-0.3.113.tar.gz
 
 [configure]
-# No configure script - libaio uses plain Makefile
+./configure --prefix=/opt/hud
 
 [build]
-make prefix=/opt/hud
+make
 
 [install]
-make prefix=/opt/hud DESTDIR=$DESTDIR install
+make DESTDIR=$DESTDIR prefix=/opt/hud install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libaio 0.3.113 installed to /opt/hud"
+echo "libaio 0.3.113 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libepoxy`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/0/libepoxy-1.5.10.huddef` | 1.5.10 | `b1b444b6f518` | `20b1d00ce8f8` | alt |
| `sources/definitions/old/packages/libepoxy-1.5.10.huddef` | 1.5.10 | `2a60e1de8cd6` | `770fdbb42373` | alt |
| `sources/definitions/old/updated-packages/libepoxy-1.5.10.huddef` | 1.5.10 | `2a60e1de8cd6` | `770fdbb42373` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/0/libepoxy-1.5.10.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/libepoxy-1.5.10.huddef</code> (21 added, 14 removed)</summary>

```diff
--- sources/definitions/old/0/libepoxy-1.5.10.huddef
+++ sources/definitions/old/packages/libepoxy-1.5.10.huddef
@@ -1,22 +1,29 @@
 # HUD Package Definition - libepoxy 1.5.10
-# OpenGL function pointer management library
+# Auto-generated for oVirt infrastructure
+
 Package: libepoxy
 Version: 1.5.10
 Architecture: x86_64
-Section: graphics
-Depends: mesa,meson,ninja
-Description: Library for handling OpenGL function pointer management
-Source: https://github.com/anholt/libepoxy/releases/download/1.5.10/libepoxy-1.5.10.tar.xz
+Section: libraries
+Depends: mesa,doxygen
+Description: libepoxy-1.5.10
+Source: https://download.gnome.org/sources/libepoxy/1.5/libepoxy-1.5.10.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ libepoxy 1.5.10 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "libepoxy 1.5.10 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libevent`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libevent/libevent-2.1.12.huddef` | 2.1.12 | `f86be0971601` | `e96fea49197e` | **POOL** |
| `sources/definitions/old/packages/libevent-2.1.12.huddef` | 2.1.12 | `da69c108ce66` | `e51da3faa884` | alt |
| `sources/definitions/old/updated-packages/libevent-2.1.12.huddef` | 2.1.12 | `f86be0971601` | `e96fea49197e` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libevent-2.1.12.huddef</code> (14 added, 11 removed)</summary>

```diff
--- pool/main/l/libevent/libevent-2.1.12.huddef
+++ sources/definitions/old/packages/libevent-2.1.12.huddef
@@ -1,26 +1,29 @@
 # HUD Package Definition - libevent 2.1.12
-# Asynchronous event notification library
+# Auto-generated for oVirt infrastructure
+
 Package: libevent
 Version: 2.1.12
 Architecture: x86_64
 Section: libraries
-Depends: openssl,python3
-Description: Asynchronous event notification software library for executing callbacks on events
+Depends: 
+Description: libevent-2.1.12
 Source: https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
+
 [configure]
-sed -i 's/python/&3/' event_rpcgen.py
-./configure --prefix=/opt/hud \
-            --disable-static \
-            CPPFLAGS="-I/opt/hud/include" \
-            LDFLAGS="-L/opt/hud/lib"
+./configure --prefix=/opt/hud
+
 [build]
-make
+make -j$(nproc)
+
 [install]
-make DESTDIR=$DESTDIR install
+make install
+
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libevent 2.1.12 installed to /opt/hud"
+echo "libevent 2.1.12 installed to /opt/hud"
+
 [prerm]
 # Stop service if running
+
 [postrm]
 ldconfig 2>/dev/null || true
```

</details>


### `libgudev`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libgudev/libgudev-238.huddef` | 238 | `cfb54766ee5b` | `a91872c9fc37` | **POOL** |
| `sources/definitions/old/packages/libgudev-238.huddef` | 238 | `d3624218306a` | `5e6070712fe1` | alt |
| `sources/definitions/old/updated-packages/libgudev-238.huddef` | 238 | `cfb54766ee5b` | `a91872c9fc37` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libgudev-238.huddef</code> (5 added, 2 removed)</summary>

```diff
--- pool/main/l/libgudev/libgudev-238.huddef
+++ sources/definitions/old/packages/libgudev-238.huddef
@@ -9,8 +9,11 @@
 Description: GObject bindings for libudev
 Source: https://download.gnome.org/sources/libgudev/238/libgudev-238.tar.xz
-MD5sum: 46da30a1c69101c3a13fa660d9ab7b73
 
 [configure]
-mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release ..
+mkdir -p build && cd build && meson setup .. \
+    --prefix=/opt/hud \
+    -Dintrospection=disabled \
+    -Dtests=disabled \
+    -Dvapi=disabled
 
 [build]
```

</details>


### `libidn2`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libidn2/libidn2-2.3.8.huddef` | 2.3.8 | `bbc458f965c9` | `90d0abd28b8f` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libidn2-2.3.8.huddef` | 2.3.8 | `a02a831d4082` | `f4b563842cab` | alt |
| `sources/definitions/old/packages/libidn2-2.3.7.huddef` | 2.3.7 | `aa0308cffc0d` | `15f6beb90ac7` | alt |
| `sources/definitions/old/updated-packages/libidn2-2.3.8.huddef` | 2.3.8 | `bbc458f965c9` | `90d0abd28b8f` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/libidn2-2.3.8.huddef</code> (4 added, 9 removed)</summary>

```diff
--- pool/main/l/libidn2/libidn2-2.3.8.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/libidn2-2.3.8.huddef
@@ -1,4 +1,5 @@
 # HUD Package Definition - libidn2 2.3.8
-# Internationalized Domain Names library (Updated from 2.3.7)
+# Internationalized Domain Names Library
+# IDNA2008/TR46 implementation for internationalized domain names
 
 Package: libidn2
@@ -7,15 +8,9 @@
 Section: libraries
 Depends: libunistring
-Description: Library for Internationalized Domain Names (IDNA2008/TR46)
+Description: Library for internationalized string handling based on IETF IDN standards
 Source: https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz
 
 [configure]
-./configure \
-    --prefix=/opt/hud \
-    --disable-static \
-    --with-libunistring-prefix=/opt/hud \
-    PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig" \
-    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
-    CPPFLAGS="-I/opt/hud/include"
+./configure --prefix=/opt/hud --disable-static
 
 [build]
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/libidn2-2.3.7.huddef</code> (5 added, 5 removed)</summary>

```diff
--- pool/main/l/libidn2/libidn2-2.3.8.huddef
+++ sources/definitions/old/packages/libidn2-2.3.7.huddef
@@ -1,12 +1,12 @@
-# HUD Package Definition - libidn2 2.3.8
-# Internationalized Domain Names library (Updated from 2.3.7)
+# HUD Package Definition - libidn2 2.3.7
+# Internationalized Domain Names library
 
 Package: libidn2
-Version: 2.3.8
+Version: 2.3.7
 Architecture: x86_64
 Section: libraries
 Depends: libunistring
 Description: Library for Internationalized Domain Names (IDNA2008/TR46)
-Source: https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz
+Source: https://ftp.gnu.org/gnu/libidn/libidn2-2.3.7.tar.gz
 
 [configure]
@@ -27,3 +27,3 @@
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libidn2 2.3.8 installed to /opt/hud"
+echo "✓ libidn2 2.3.7 installed to /opt/hud"
```

</details>


### `libjpeg`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libjpeg/libjpeg-3.0.1.huddef` | 3.0.1 | `ad4a45808105` | `a43f3aad7c56` | **POOL** |
| `sources/definitions/old/packages/libjpeg-3.0.1.huddef` | 3.0.1 | `21fb8d1db7df` | `32eed1c7c12f` | alt |
| `sources/definitions/old/updated-packages/libjpeg-3.0.1.huddef` | 3.0.1 | `ad4a45808105` | `a43f3aad7c56` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libjpeg-3.0.1.huddef</code> (14 added, 16 removed)</summary>

```diff
--- pool/main/l/libjpeg/libjpeg-3.0.1.huddef
+++ sources/definitions/old/packages/libjpeg-3.0.1.huddef
@@ -1,5 +1,4 @@
-# HUD Package Definition - libjpeg-turbo 3.0.1
-# JPEG image codec library - Based on LFS 12.4
-# Note: Requires CMake and optionally NASM/Yasm for SIMD optimization
+# HUD Package Definition - libjpeg 3.0.1
+# Auto-generated for oVirt infrastructure
 
 Package: libjpeg
@@ -7,25 +6,24 @@
 Architecture: x86_64
 Section: libraries
-Depends: cmake, nasm
-Description: libjpeg-turbo - high-speed JPEG codec library with SIMD
+Depends: cmake,nasm
+Description: libjpeg-turbo-3.0.1
 Source: https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-3.0.1.tar.gz
 
 [configure]
-mkdir -p build && cd build && \
-cmake -DCMAKE_INSTALL_PREFIX=/opt/hud \
-      -DCMAKE_BUILD_TYPE=RELEASE \
-      -DENABLE_STATIC=FALSE \
-      -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib \
-      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
-      -DCMAKE_SKIP_INSTALL_RPATH=ON \
-      ..
+./configure --prefix=/opt/hud
 
 [build]
-cd build && make -j$(nproc)
+make -j$(nproc)
 
 [install]
-cd build && make DESTDIR=$DESTDIR install
+make install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libjpeg-turbo 3.0.1 installed to /opt/hud"
+echo "libjpeg 3.0.1 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libndp`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libndp/libndp-1.9.huddef` | 1.9 | `de3b77ae9fee` | `c29a03582f31` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/libndp-1.9.huddef` | 1.9 | `de3b77ae9fee` | `c29a03582f31` | **= POOL** |
| `sources/definitions/old/packages/libndp-1.9.huddef` | 1.9 | `c6b862e0c844` | `d7c20e740893` | alt |
| `sources/definitions/old/updated-packages/libndp-1.9.huddef` | 1.9 | `596dd4a3bbef` | `807a4d2a1e7e` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/libndp-1.9.huddef</code> (8 added, 15 removed)</summary>

```diff
--- pool/main/l/libndp/libndp-1.9.huddef
+++ sources/definitions/old/packages/libndp-1.9.huddef
@@ -1,27 +1,20 @@
 # HUD Package Definition - libndp 1.9
-# Library for IPv6 Neighbor Discovery Protocol
-# Required by NetworkManager
+# Library for Neighbor Discovery Protocol
 
 Package: libndp
 Version: 1.9
 Architecture: x86_64
-Section: libraries
+Section: network
 Depends:
 Description: Library for IPv6 Neighbor Discovery Protocol
-Source: https://github.com/jpirko/libndp/releases/download/v1.9/libndp-1.9.tar.gz
+Source: https://github.com/jpirko/libndp/archive/refs/tags/v1.9.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-./configure --prefix=/opt/hud \
-            --disable-static
+./autogen.sh
+./configure \
+    --prefix=/opt/hud \
+    --disable-static
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make -j$(nproc)
 
@@ -30,4 +23,4 @@
 
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
 echo "✓ libndp 1.9 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/updated-packages/libndp-1.9.huddef</code> (8 added, 20 removed)</summary>

```diff
--- pool/main/l/libndp/libndp-1.9.huddef
+++ sources/definitions/old/updated-packages/libndp-1.9.huddef
@@ -1,33 +1,21 @@
 # HUD Package Definition - libndp 1.9
-# Library for IPv6 Neighbor Discovery Protocol
-# Required by NetworkManager
-
+# Library for Neighbor Discovery Protocol
 Package: libndp
 Version: 1.9
 Architecture: x86_64
-Section: libraries
+Section: network
 Depends:
-Description: Library for IPv6 Neighbor Discovery Protocol
-Source: https://github.com/jpirko/libndp/releases/download/v1.9/libndp-1.9.tar.gz
-
+Description: Wrapper library for IPv6 Neighbor Discovery Protocol with ndptool utility
+Source: http://libndp.org/files/libndp-1.9.tar.gz
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
 ./configure --prefix=/opt/hud \
+            --sysconfdir=/opt/hud/etc \
+            --localstatedir=/opt/hud/var \
             --disable-static
-
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
 echo "✓ libndp 1.9 installed to /opt/hud"
```

</details>


### `libpng`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libpng/libpng-1.6.50.huddef` | 1.6.50 | `aee876cf3ac6` | `d6262febf689` | **POOL** |
| `sources/definitions/old/0/libpng-1.6.50.huddef` | 1.6.50 | `68b42d7c0ee1` | `4c71600c63a3` | alt |
| `sources/definitions/old/packages/libpng-1.6.50.huddef` | 1.6.50 | `aee876cf3ac6` | `d6262febf689` | **= POOL** |
| `sources/definitions/old/updated-packages/libpng-1.6.50.huddef` | 1.6.50 | `aee876cf3ac6` | `d6262febf689` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libpng-1.6.50.huddef</code> (9 added, 22 removed)</summary>

```diff
--- pool/main/l/libpng/libpng-1.6.50.huddef
+++ sources/definitions/old/0/libpng-1.6.50.huddef
@@ -1,31 +1,18 @@
 # HUD Package Definition - libpng 1.6.50
-# Auto-generated for oVirt infrastructure
-
+# PNG reference library
 Package: libpng
 Version: 1.6.50
 Architecture: x86_64
-Section: libraries
-Depends: 
-Description: libpng-1.6.50
+Section: graphics
+Depends: zlib
+Description: PNG reference library for reading, writing, and manipulating PNG images
 Source: https://downloads.sourceforge.net/libpng/libpng-1.6.50.tar.xz
-
 [configure]
-./configure --prefix=/opt/hud
-
+./configure --prefix=/opt/hud --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
-make install &&
-mkdir -v /usr/share/doc/libpng-1.6.50 &&
-cp -v README libpng-manual.txt /usr/share/doc/libpng-1.6.50
-
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
-echo "libpng 1.6.50 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libpng 1.6.50 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libpsl`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libpsl/libpsl-0.21.5.huddef` | 0.21.5 | `70b770aeeda2` | `23d5e8eb565b` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/libpsl-0.21.5.huddef` | 0.21.5 | `70b770aeeda2` | `23d5e8eb565b` | **= POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libpsl-0.21.5.huddef` | 0.21.5 | `5cb693793734` | `28ee14a08165` | alt |
| `sources/definitions/old/packages/libpsl-0.21.5.huddef` | 0.21.5 | `fe7277d4298d` | `88aa8e6afa9f` | alt |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/libpsl-0.21.5.huddef</code> (7 added, 19 removed)</summary>

```diff
--- pool/main/l/libpsl/libpsl-0.21.5.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/libpsl-0.21.5.huddef
@@ -1,5 +1,5 @@
 # HUD Package Definition - libpsl 0.21.5
-# Public Suffix List library
-# Required by NetworkManager for domain resolution
+# Public Suffix List Library
+# Library for accessing and resolving information from the Public Suffix List
 
 Package: libpsl
@@ -8,30 +8,18 @@
 Section: libraries
 Depends: libidn2, libunistring
-Description: Library for accessing the Public Suffix List (PSL)
+Description: Library for accessing and resolving information from the Public Suffix List (PSL)
 Source: https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
 mkdir -p build
 cd build
 
-meson setup --prefix=/opt/hud \
-            --buildtype=release \
-            ..
+meson setup ..              \
+    --prefix=/opt/hud       \
+    --buildtype=release
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 cd build
 ninja
-
-[check]
-cd build
-ninja test
 
 [install]
@@ -40,4 +28,4 @@
 
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
 echo "✓ libpsl 0.21.5 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/libpsl-0.21.5.huddef</code> (9 added, 26 removed)</summary>

```diff
--- pool/main/l/libpsl/libpsl-0.21.5.huddef
+++ sources/definitions/old/packages/libpsl-0.21.5.huddef
@@ -1,5 +1,4 @@
 # HUD Package Definition - libpsl 0.21.5
 # Public Suffix List library
-# Required by NetworkManager for domain resolution
 
 Package: libpsl
@@ -7,37 +6,21 @@
 Architecture: x86_64
 Section: libraries
-Depends: libidn2, libunistring
-Description: Library for accessing the Public Suffix List (PSL)
+Depends: libidn2,libunistring
+Description: Library to handle the Public Suffix List
 Source: https://github.com/rockdaboot/libpsl/releases/download/0.21.5/libpsl-0.21.5.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-mkdir -p build
-cd build
-
-meson setup --prefix=/opt/hud \
-            --buildtype=release \
-            ..
+mkdir -p build && cd build && meson setup .. \
+    --prefix=/opt/hud \
+    -Druntime=libidn2 \
+    -Dbuiltin=true
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
-ninja
-
-[check]
-cd build
-ninja test
+cd build && ninja -j$(nproc)
 
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+cd build && DESTDIR=$DESTDIR ninja install
 
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
 echo "✓ libpsl 0.21.5 installed to /opt/hud"
```

</details>


### `libslirp`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libslirp/libslirp-4.9.1.huddef` | 4.9.1 | `42d47627bb2a` | `07f74792f666` | **POOL** |
| `sources/definitions/old/packages/libslirp-4.9.1.huddef` | 4.9.1 | `da4f867b5375` | `db4e9c32ac44` | alt |
| `sources/definitions/old/updated-packages/libpsl-0.21.5.huddef` | 4.9.1 | `db4ace84b04c` | `067ef08ce278` | alt |
| `sources/definitions/old/updated-packages/libslirp-4.9.1.huddef` | 4.9.1 | `240aa5bf8673` | `de7177e7410d` | alt |
| `sources/definitions/qemu-huddef/libslirp-4.9.1.huddef` | 4.9.1 | `42d47627bb2a` | `07f74792f666` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libslirp-4.9.1.huddef</code> (20 added, 19 removed)</summary>

```diff
--- pool/main/l/libslirp/libslirp-4.9.1.huddef
+++ sources/definitions/old/packages/libslirp-4.9.1.huddef
@@ -1,28 +1,29 @@
 # HUD Package Definition - libslirp 4.9.1
-# User-mode networking library (recommended for QEMU)
-# Provides -netdev user support for QEMU
+# Auto-generated for oVirt infrastructure
+
 Package: libslirp
 Version: 4.9.1
 Architecture: x86_64
 Section: libraries
-Depends: glib
-Description: General purpose TCP-IP emulator library used for user-mode networking
-Source: https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.gz
+Depends: glib2
+Description: libslirp-4.9.1
+Source: https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.bz2
+
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud ..
+./configure --prefix=/opt/hud
+
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-ldconfig
-echo "✓ libslirp 4.9.1 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "libslirp 4.9.1 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/updated-packages/libpsl-0.21.5.huddef</code> (13 added, 18 removed)</summary>

```diff
--- pool/main/l/libslirp/libslirp-4.9.1.huddef
+++ sources/definitions/old/updated-packages/libpsl-0.21.5.huddef
@@ -1,28 +1,23 @@
 # HUD Package Definition - libslirp 4.9.1
-# User-mode networking library (recommended for QEMU)
-# Provides -netdev user support for QEMU
+# User-mode networking library for virtual machines
+
 Package: libslirp
 Version: 4.9.1
 Architecture: x86_64
 Section: libraries
-Depends: glib
-Description: General purpose TCP-IP emulator library used for user-mode networking
-Source: https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.gz
+Depends: glib2
+Description: General purpose TCP-IP emulator used by virtual machines
+Source: https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.bz2
+
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud ..
+mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release ..
+
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
-ninja
+cd build && ninja -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+cd build && DESTDIR=$DESTDIR ninja install
+
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
 echo "✓ libslirp 4.9.1 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/updated-packages/libslirp-4.9.1.huddef</code> (14 added, 18 removed)</summary>

```diff
--- pool/main/l/libslirp/libslirp-4.9.1.huddef
+++ sources/definitions/old/updated-packages/libslirp-4.9.1.huddef
@@ -1,28 +1,24 @@
 # HUD Package Definition - libslirp 4.9.1
-# User-mode networking library (recommended for QEMU)
-# Provides -netdev user support for QEMU
+# User-mode networking library
+
 Package: libslirp
 Version: 4.9.1
 Architecture: x86_64
 Section: libraries
-Depends: glib
-Description: General purpose TCP-IP emulator library used for user-mode networking
-Source: https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.gz
+Depends: glib2
+Description: User-mode networking library used by virtual machines, containers or various tools
+Source: https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.bz2
+MD5sum: eefd3b2375453cf9d07375c389441685
+
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud ..
+mkdir -p build && cd build && meson setup --prefix=/opt/hud --buildtype=release ..
+
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
-ninja
+cd build && ninja -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+cd build && DESTDIR=$DESTDIR ninja install
+
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
 echo "✓ libslirp 4.9.1 installed to /opt/hud"
```

</details>


### `libsndfile`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libsndfile/libsndfile-1.2.2.huddef` | 1.2.2 | `3772fb27d4c7` | `890b640cf384` | **POOL** |
| `sources/definitions/old/packages/libsndfile-1.2.2.huddef` | 1.2.2 | `abb09db68149` | `5482127dfbf3` | alt |
| `sources/definitions/old/updated-packages/libsndfile-1.2.2.huddef` | 1.2.2 | `3772fb27d4c7` | `890b640cf384` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libsndfile-1.2.2.huddef</code> (12 added, 8 removed)</summary>

```diff
--- pool/main/l/libsndfile/libsndfile-1.2.2.huddef
+++ sources/definitions/old/packages/libsndfile-1.2.2.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - libsndfile 1.2.2
-# Library for reading and writing audio files
+# Auto-generated for oVirt infrastructure
 
 Package: libsndfile
@@ -6,12 +6,10 @@
 Architecture: x86_64
 Section: libraries
-Depends: flac,opus,libvorbis
-Description: Library of C routines for reading and writing files containing sampled audio data
+Depends: opus,flac,mpg123,alsa-lib,speex
+Description: libsndfile-1.2.2
 Source: https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz
-MD5sum: 04e2e6f726da7c5dc87f8cf72f250d04
 
 [configure]
-sed '/typedef enum/,/bool ;/d' -i src/ALAC/alac_{en,de}coder.c
-./configure --prefix=/opt/hud --docdir=/opt/hud/share/doc/libsndfile-1.2.2
+./configure --prefix=/opt/hud
 
 [build]
@@ -19,7 +17,13 @@
 
 [install]
-make DESTDIR=$DESTDIR install
+make install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libsndfile 1.2.2 installed to /opt/hud"
+echo "libsndfile 1.2.2 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libtasn1`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libtasn1/libtasn1-4.20.0.huddef` | 4.20.0 | `104ed7459ba0` | `f6e6cd41c7b8` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libtasn1-4.20.0.huddef` | 4.20.0 | `db9ee9381e65` | `aadb90e6e78e` | alt |
| `sources/definitions/old/packages/libtasn1-4.20.0.huddef` | 4.20.0 | `62fb2d35ac5d` | `8ca46bef52f1` | alt |
| `sources/definitions/old/updated-packages/libtasn1-4.20.0.huddef` | 4.20.0 | `104ed7459ba0` | `f6e6cd41c7b8` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/libtasn1-4.20.0.huddef</code> (6 added, 12 removed)</summary>

```diff
--- pool/main/l/libtasn1/libtasn1-4.20.0.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/libtasn1-4.20.0.huddef
@@ -1,12 +1,12 @@
 # HUD Package Definition - libtasn1 4.20.0
-# Based on BLFS 12.4 documentation
-# Note: Required dependency for p11-kit
+# ASN.1 Library
+# Library for Abstract Syntax Notation One (ASN.1) structures
 
 Package: libtasn1
 Version: 4.20.0
 Architecture: x86_64
-Section: security
+Section: libraries
 Depends:
-Description: ASN.1 library used for DER/BER encoding/decoding
+Description: Library for ASN.1 structures management according to ITU-T X.680
 Source: https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz
 
@@ -18,13 +18,7 @@
 
 [install]
-make install DESTDIR=$DESTDIR
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "libtasn1 4.20.0 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libtasn1 4.20.0 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/libtasn1-4.20.0.huddef</code> (7 added, 8 removed)</summary>

```diff
--- pool/main/l/libtasn1/libtasn1-4.20.0.huddef
+++ sources/definitions/old/packages/libtasn1-4.20.0.huddef
@@ -1,16 +1,15 @@
 # HUD Package Definition - libtasn1 4.20.0
-# Based on BLFS 12.4 documentation
-# Note: Required dependency for p11-kit
+# Auto-generated for oVirt infrastructure
 
 Package: libtasn1
 Version: 4.20.0
 Architecture: x86_64
-Section: security
-Depends:
-Description: ASN.1 library used for DER/BER encoding/decoding
+Section: libraries
+Depends: 
+Description: libtasn1-4.20.0
 Source: https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz
 
 [configure]
-./configure --prefix=/opt/hud --disable-static
+./configure --prefix=/opt/hud
 
 [build]
@@ -18,5 +17,5 @@
 
 [install]
-make install DESTDIR=$DESTDIR
+make install
 
 [postinst]
@@ -25,5 +24,5 @@
 
 [prerm]
-# No services to stop
+# Stop service if running
 
 [postrm]
```

</details>


### `libtiff`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libtiff/libtiff-4.7.0.huddef` | 4.7.0 | `c8e61844178a` | `d0fee76d836f` | **POOL** |
| `sources/definitions/old/0/libtiff-4.7.0.huddef` | 4.7.0 | `b108d10ecdb3` | `9ab793aad657` | alt |
| `sources/definitions/old/packages/libtiff-4.7.0.huddef` | 4.7.0 | `c8e61844178a` | `d0fee76d836f` | **= POOL** |
| `sources/definitions/old/updated-packages/libtiff-4.7.0.huddef` | 4.7.0 | `c8e61844178a` | `d0fee76d836f` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libtiff-4.7.0.huddef</code> (13 added, 20 removed)</summary>

```diff
--- pool/main/l/libtiff/libtiff-4.7.0.huddef
+++ sources/definitions/old/0/libtiff-4.7.0.huddef
@@ -1,29 +1,22 @@
 # HUD Package Definition - libtiff 4.7.0
-# Auto-generated for oVirt infrastructure
-
+# TIFF library and utilities
 Package: libtiff
 Version: 4.7.0
 Architecture: x86_64
-Section: libraries
-Depends: sphinx,freeglut,cmake,libjpeg,libwebp
-Description: libtiff-4.7.0
+Section: graphics
+Depends: libjpeg-turbo,zlib,xz
+Description: Library and utilities for reading and writing TIFF files
 Source: https://download.osgeo.org/libtiff/tiff-4.7.0.tar.gz
-
 [configure]
-./configure --prefix=/opt/hud
-
+mkdir -p build
+cd build
+cmake -DCMAKE_INSTALL_PREFIX=/opt/hud -DCMAKE_BUILD_TYPE=Release ..
 [build]
-make -j$(nproc)
-
+cd build
+make
 [install]
-make install
-
+cd build
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
-echo "libtiff 4.7.0 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libtiff 4.7.0 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libtirpc`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libtirpc/libtirpc-1.3.7.huddef` | 1.3.7 | `fdd69609951f` | `f72b063d363c` | **POOL** |
| `sources/definitions/14 Feb 2026/libtirpc-1.3.6.huddef` | 1.3.6 | `7520976d39c1` | `c63bd926b82d` | alt |
| `sources/definitions/libtirpc-1.3.6.huddef` | 1.3.6 | `c28c14459486` | `667f88f2dc7f` | alt |
| `sources/definitions/libtirpc-1.3.7.huddef` | 1.3.7 | `fdd69609951f` | `f72b063d363c` | **= POOL** |

<details><summary>diff → <code>sources/definitions/14 Feb 2026/libtirpc-1.3.6.huddef</code> (10 added, 7 removed)</summary>

```diff
--- pool/main/l/libtirpc/libtirpc-1.3.7.huddef
+++ sources/definitions/14 Feb 2026/libtirpc-1.3.6.huddef
@@ -1,16 +1,16 @@
-# HUD Package Definition - libtirpc 1.3.7 (NEWER VERSION)
+# HUD Package Definition - libtirpc 1.3.6 (FIXED)
 # Transport Independent RPC library (replaces older glibc RPC)
 # Required by: glusterfs, nfs-utils
 # Reference: https://sourceforge.net/projects/libtirpc/
 #
-# Using version 1.3.7 which has better GCC compatibility
+# FIX: Added compiler flags to handle old-style C code
 
 Package: libtirpc
-Version: 1.3.7
+Version: 1.3.6
 Architecture: x86_64
 Section: libraries
 Depends: 
 Description: Transport Independent RPC library
-Source: https://downloads.sourceforge.net/libtirpc/libtirpc-1.3.7.tar.bz2
+Source: https://downloads.sourceforge.net/libtirpc/libtirpc-1.3.6.tar.bz2
 
 [configure]
@@ -18,5 +18,7 @@
 export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include -O2"
+
+# Add flags to handle old-style C code and warnings
+export CFLAGS="-I/opt/hud/include -Wno-error=old-style-definition -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types"
 export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
 
@@ -31,5 +33,6 @@
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 
-make -j$(nproc)
+# Build with warnings as non-fatal
+make -j$(nproc) CFLAGS="-Wno-error"
 
 [install]
@@ -58,5 +61,5 @@
 echo ""
 echo "============================================"
-echo "libtirpc 1.3.7 installed successfully"
+echo "libtirpc 1.3.6 installed successfully"
 echo "============================================"
 echo ""
```

</details>

<details><summary>diff → <code>sources/definitions/libtirpc-1.3.6.huddef</code> (11 added, 7 removed)</summary>

```diff
--- pool/main/l/libtirpc/libtirpc-1.3.7.huddef
+++ sources/definitions/libtirpc-1.3.6.huddef
@@ -1,16 +1,16 @@
-# HUD Package Definition - libtirpc 1.3.7 (NEWER VERSION)
+# HUD Package Definition - libtirpc 1.3.6 (WORKING FIX)
 # Transport Independent RPC library (replaces older glibc RPC)
 # Required by: glusterfs, nfs-utils
 # Reference: https://sourceforge.net/projects/libtirpc/
 #
-# Using version 1.3.7 which has better GCC compatibility
+# FIX: Disable -Werror during configure AND build
 
 Package: libtirpc
-Version: 1.3.7
+Version: 1.3.6
 Architecture: x86_64
 Section: libraries
 Depends: 
 Description: Transport Independent RPC library
-Source: https://downloads.sourceforge.net/libtirpc/libtirpc-1.3.7.tar.bz2
+Source: https://downloads.sourceforge.net/libtirpc/libtirpc-1.3.6.tar.bz2
 
 [configure]
@@ -18,4 +18,6 @@
 export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+
+# Critical: Disable all -Werror flags
 export CFLAGS="-I/opt/hud/include -O2"
 export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
@@ -25,5 +27,6 @@
             --libdir=/opt/hud/lib64 \
             --disable-static \
-            --disable-gssapi
+            --disable-gssapi \
+            --disable-werror
 
 [build]
@@ -31,5 +34,6 @@
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 
-make -j$(nproc)
+# Override any CFLAGS with warnings disabled
+make -j$(nproc) AM_CFLAGS="-O2 -w"
 
 [install]
@@ -58,5 +62,5 @@
 echo ""
 echo "============================================"
-echo "libtirpc 1.3.7 installed successfully"
+echo "libtirpc 1.3.6 installed successfully"
 echo "============================================"
 echo ""
```

</details>


### `libunistring`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libunistring/libunistring-1.3.huddef` | 1.3 | `0fb262688eb5` | `4a79ed58bf18` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/libunistring-1.3.huddef` | 1.3 | `fc88db1a8b0c` | `1f6ee96e3eb3` | alt |
| `sources/definitions/old/packages/libunistring-1.3.huddef` | 1.3 | `cedaf587290e` | `9daccdfc88cd` | alt |
| `sources/definitions/old/updated-packages/libunistring-1.3.huddef` | 1.3 | `0fb262688eb5` | `4a79ed58bf18` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/libunistring-1.3.huddef</code> (9 added, 13 removed)</summary>

```diff
--- pool/main/l/libunistring/libunistring-1.3.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/libunistring-1.3.huddef
@@ -1,16 +1,18 @@
 # HUD Package Definition - libunistring 1.3
-# Based on BLFS 12.4 documentation
-# Note: Recommended dependency for GnuTLS
+# Unicode String Library
+# Functions for manipulating Unicode strings
 
 Package: libunistring
 Version: 1.3
 Architecture: x86_64
-Section: misc
+Section: libraries
 Depends:
-Description: Library for manipulating Unicode strings and C strings according to Unicode standard
+Description: Library providing functions for manipulating Unicode strings and C strings according to Unicode standard
 Source: https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.xz
 
 [configure]
-./configure --prefix=/opt/hud --disable-static
+./configure --prefix=/opt/hud    \
+            --disable-static     \
+            --docdir=/opt/hud/share/doc/libunistring-1.3
 
 [build]
@@ -18,13 +20,7 @@
 
 [install]
-make install DESTDIR=$DESTDIR
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "libunistring 1.3 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libunistring 1.3 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/libunistring-1.3.huddef</code> (9 added, 14 removed)</summary>

```diff
--- pool/main/l/libunistring/libunistring-1.3.huddef
+++ sources/definitions/old/packages/libunistring-1.3.huddef
@@ -1,16 +1,17 @@
 # HUD Package Definition - libunistring 1.3
-# Based on BLFS 12.4 documentation
-# Note: Recommended dependency for GnuTLS
+# Unicode string library
 
 Package: libunistring
 Version: 1.3
 Architecture: x86_64
-Section: misc
+Section: libraries
 Depends:
-Description: Library for manipulating Unicode strings and C strings according to Unicode standard
-Source: https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.xz
+Description: Library for manipulating Unicode strings
+Source: https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.gz
 
 [configure]
-./configure --prefix=/opt/hud --disable-static
+./configure \
+    --prefix=/opt/hud \
+    --disable-static
 
 [build]
@@ -18,13 +19,7 @@
 
 [install]
-make install DESTDIR=$DESTDIR
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "libunistring 1.3 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libunistring 1.3 installed to /opt/hud"
```

</details>


### `libvirt`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libvirt/libvirt-10.10.0.huddef` | 10.10.0 | `c344aa7999a9` | `7dcb70e5cbfb` | **POOL** |
| `sources/definitions/13 Feb 2026/libvirt-10.10.0.huddef` | 10.10.0 | `0d8521f6f6b6` | `4be40a71de92` | alt |
| `sources/definitions/libvirt/libvirt-10.10.0.huddef` | 10.10.0 | `2b521891536e` | `11c162c93a23` | alt |
| `sources/definitions/libvirt_9feb_2026/libvirt-10.10.0.huddef` | 10.10.0 | `c344aa7999a9` | `7dcb70e5cbfb` | **= POOL** |
| `sources/definitions/old/packages/libvirt-10.10.0.huddef` | 10.10.0 | `e76fdfcd419d` | `8f814c6884c4` | alt |
| `sources/definitions/old/updated-packages/libvirt-10.10.0.huddef` | 10.10.0 | `e76fdfcd419d` | `8f814c6884c4` | alt |

<details><summary>diff → <code>sources/definitions/13 Feb 2026/libvirt-10.10.0.huddef</code> (53 added, 0 removed)</summary>

```diff
--- pool/main/l/libvirt/libvirt-10.10.0.huddef
+++ sources/definitions/13 Feb 2026/libvirt-10.10.0.huddef
@@ -83,4 +83,5 @@
 cd build
 DESTDIR=$DESTDIR ninja install
+
 # Ensure key binaries are copied to standard locations
 mkdir -p $DESTDIR/usr/bin $DESTDIR/usr/sbin
@@ -92,5 +93,57 @@
 chmod +x $DESTDIR/usr/sbin/virtqemud $DESTDIR/usr/sbin/virtnetworkd 2>/dev/null || true
 
+# Copy libraries to /opt/hud/lib (they might only be in pkg)
+mkdir -p $DESTDIR/opt/hud/lib
+cp -f src/libvirt.so.0.10010.0 $DESTDIR/opt/hud/lib/ 2>/dev/null || true
+cp -f src/libvirt-lxc.so.0.10010.0 $DESTDIR/opt/hud/lib/ 2>/dev/null || true
+cp -f src/libvirt-qemu.so.0.10010.0 $DESTDIR/opt/hud/lib/ 2>/dev/null || true
+cp -f src/libvirt-admin.so.0.10010.0 $DESTDIR/opt/hud/lib/ 2>/dev/null || true
+
+# Copy driver modules
+mkdir -p $DESTDIR/opt/hud/lib/libvirt/connection-driver
+mkdir -p $DESTDIR/opt/hud/lib/libvirt/lock-driver
+mkdir -p $DESTDIR/opt/hud/lib/libvirt/storage-backend
+mkdir -p $DESTDIR/opt/hud/lib/libvirt/storage-file
+cp -f src/libvirt_driver_*.so $DESTDIR/opt/hud/lib/libvirt/connection-driver/ 2>/dev/null || true
+cp -f src/libvirt_storage_backend_*.so $DESTDIR/opt/hud/lib/libvirt/storage-backend/ 2>/dev/null || true
+cp -f src/libvirt_storage_file_*.so $DESTDIR/opt/hud/lib/libvirt/storage-file/ 2>/dev/null || true
+cp -f src/lockd.so $DESTDIR/opt/hud/lib/libvirt/lock-driver/ 2>/dev/null || true
+
+# Also copy to /usr/lib/libvirt (virtqemud looks here)
+mkdir -p $DESTDIR/usr/lib/libvirt/connection-driver
+mkdir -p $DESTDIR/usr/lib/libvirt/lock-driver
+mkdir -p $DESTDIR/usr/lib/libvirt/storage-backend
+mkdir -p $DESTDIR/usr/lib/libvirt/storage-file
+cp -f src/libvirt_driver_*.so $DESTDIR/usr/lib/libvirt/connection-driver/ 2>/dev/null || true
+cp -f src/libvirt_storage_backend_*.so $DESTDIR/usr/lib/libvirt/storage-backend/ 2>/dev/null || true
+cp -f src/libvirt_storage_file_*.so $DESTDIR/usr/lib/libvirt/storage-file/ 2>/dev/null || true
+cp -f src/lockd.so $DESTDIR/usr/lib/libvirt/lock-driver/ 2>/dev/null || true
+
+# Also copy to /usr/lib for compatibility
+mkdir -p $DESTDIR/usr/lib/libvirt/connection-driver
+mkdir -p $DESTDIR/usr/lib/libvirt/lock-driver
+mkdir -p $DESTDIR/usr/lib/libvirt/storage-backend
+mkdir -p $DESTDIR/usr/lib/libvirt/storage-file
+cp -f src/libvirt_driver_*.so $DESTDIR/usr/lib/libvirt/connection-driver/ 2>/dev/null || true
+cp -f src/libvirt_storage_backend_*.so $DESTDIR/usr/lib/libvirt/storage-backend/ 2>/dev/null || true
+cp -f src/libvirt_storage_file_*.so $DESTDIR/usr/lib/libvirt/storage-file/ 2>/dev/null || true
+cp -f src/lockd.so $DESTDIR/usr/lib/libvirt/lock-driver/ 2>/dev/null || true
+
 [postinst]
+# Add library paths to ldconfig
+echo "/opt/hud/lib" > /etc/ld.so.conf.d/hud.conf
+echo "/opt/hud/lib64" >> /etc/ld.so.conf.d/hud.conf
+ldconfig
+
+# Create library symlinks
+cd /opt/hud/lib
+ln -sf libvirt.so.0.10010.0 libvirt.so.0 2>/dev/null || true
+ln -sf libvirt.so.0 libvirt.so 2>/dev/null || true
+ln -sf libvirt-lxc.so.0.10010.0 libvirt-lxc.so.0 2>/dev/null || true
+ln -sf libvirt-lxc.so.0 libvirt-lxc.so 2>/dev/null || true
+ln -sf libvirt-qemu.so.0.10010.0 libvirt-qemu.so.0 2>/dev/null || true
+ln -sf libvirt-qemu.so.0 libvirt-qemu.so 2>/dev/null || true
+ln -sf libvirt-admin.so.0.10010.0 libvirt-admin.so.0 2>/dev/null || true
+ln -sf libvirt-admin.so.0 libvirt-admin.so 2>/dev/null || true
 ldconfig
 
```

</details>

<details><summary>diff → <code>sources/definitions/libvirt/libvirt-10.10.0.huddef</code> (18 added, 236 removed)</summary>

```diff
--- pool/main/l/libvirt/libvirt-10.10.0.huddef
+++ sources/definitions/libvirt/libvirt-10.10.0.huddef
@@ -1,15 +1,5 @@
 # HUD Package Definition - libvirt 10.10.0
-# Virtualization API for managing QEMU/KVM hypervisors
-# Uses modular daemon architecture (virtqemud, virtnetworkd, etc.)
+# Virtualization API for managing QEMU/KVM, Xen, and other hypervisors
 # Reference: https://libvirt.org/
-#
-# FIXES APPLIED:
-# - Modular daemons (virtqemud, virtnetworkd) instead of monolithic libvirtd
-# - Socket config files for daemon-created sockets (not systemd socket activation)
-# - nftables firewall backend for compatibility with firewalld
-# - Proper systemd services with timeouts
-# - Copies missing binaries (virsh, virt-host-validate, virtqemud, virtnetworkd)
-# - Creates firewalld libvirt zone
-# - Polkit rules for libvirt group
 
 Package: libvirt
@@ -17,5 +7,5 @@
 Architecture: x86_64
 Section: virtualization
-Depends: qemu, python3, glib, libxml2, yajl, libpciaccess, numactl, polkit, dbus, libnl, gnutls, libgcrypt, curl, libssh2, nftables, dnsmasq, dmidecode
+Depends: qemu, python3, glib, libxml2, yajl, libpciaccess, numactl, polkit, dbus, libnl, gnutls, libgcrypt, curl, libssh2
 Description: Virtualization API library for managing hypervisors (QEMU/KVM)
 Source: https://download.libvirt.org/libvirt-10.10.0.tar.xz
@@ -83,20 +73,9 @@
 cd build
 DESTDIR=$DESTDIR ninja install
-# Ensure key binaries are copied to standard locations
-mkdir -p $DESTDIR/usr/bin $DESTDIR/usr/sbin
-cp -f tools/virsh $DESTDIR/usr/bin/virsh 2>/dev/null || true
-cp -f tools/virt-host-validate $DESTDIR/usr/bin/virt-host-validate 2>/dev/null || true
-cp -f src/virtqemud $DESTDIR/usr/sbin/virtqemud 2>/dev/null || true
-cp -f src/virtnetworkd $DESTDIR/usr/sbin/virtnetworkd 2>/dev/null || true
-chmod +x $DESTDIR/usr/bin/virsh $DESTDIR/usr/bin/virt-host-validate 2>/dev/null || true
-chmod +x $DESTDIR/usr/sbin/virtqemud $DESTDIR/usr/sbin/virtnetworkd 2>/dev/null || true
 
 [postinst]
 ldconfig
-
-# Create directories
 install -vdm755 /etc/libvirt
 install -vdm755 /etc/libvirt/qemu
-install -vdm755 /etc/libvirt/qemu/networks
 install -vdm755 /var/lib/libvirt
 install -vdm755 /var/lib/libvirt/images
@@ -104,7 +83,4 @@
 install -vdm755 /var/log/libvirt
 install -vdm755 /var/run/libvirt
-install -vdm755 /var/run/libvirt/qemu
-
-# Create groups and users
 groupadd -fg 36 kvm 2>/dev/null || true
 groupadd -fg 27 libvirt 2>/dev/null || true
@@ -112,218 +88,24 @@
 chown -R libvirt:libvirt /var/lib/libvirt 2>/dev/null || true
 chown -R libvirt:libvirt /var/log/libvirt 2>/dev/null || true
-
-# Ensure binaries are in place (fallback to build directory)
-test -f /usr/bin/virsh || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/tools/virsh /usr/bin/virsh 2>/dev/null || true
-test -f /usr/bin/virt-host-validate || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/tools/virt-host-validate /usr/bin/virt-host-validate 2>/dev/null || true
-test -f /usr/sbin/virtqemud || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/src/virtqemud /usr/sbin/virtqemud 2>/dev/null || true
-test -f /usr/sbin/virtnetworkd || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/src/virtnetworkd /usr/sbin/virtnetworkd 2>/dev/null || true
-chmod +x /usr/bin/virsh /usr/bin/virt-host-validate /usr/sbin/virtqemud /usr/sbin/virtnetworkd 2>/dev/null || true
-
-# ============================================================
-# DAEMON SOCKET CONFIGURATION (CRITICAL FOR SOCKET CREATION)
-# ============================================================
-# These config files tell the daemons to create their own sockets
-# instead of relying on systemd socket activation
-
-cat > /etc/libvirt/virtqemud.conf << 'EOFCONF'
-# virtqemud socket configuration
-# Daemon creates its own sockets (not systemd socket activation)
-unix_sock_group = "libvirt"
-unix_sock_ro_perms = "0777"
-unix_sock_rw_perms = "0770"
-unix_sock_admin_perms = "0700"
-unix_sock_dir = "/var/run/libvirt"
-EOFCONF
-
-cat > /etc/libvirt/virtnetworkd.conf << 'EOFCONF'
-# virtnetworkd socket configuration
-unix_sock_group = "libvirt"
-unix_sock_ro_perms = "0777"
-unix_sock_rw_perms = "0770"
-unix_sock_admin_perms = "0700"
-unix_sock_dir = "/var/run/libvirt"
-EOFCONF
-
-# Configure network to use nftables backend (works with firewalld)
-cat > /etc/libvirt/network.conf << 'EOFCONF'
-# Network driver configuration
-# Use nftables backend for firewalld compatibility
-firewall_backend = "nftables"
-EOFCONF
-
-# ============================================================
-# FIREWALLD LIBVIRT ZONE
-# ============================================================
-install -vdm755 /etc/firewalld/zones
-cat > /etc/firewalld/zones/libvirt.xml << 'EOFXML'
-<?xml version="1.0" encoding="utf-8"?>
-<zone target="ACCEPT">
-  <short>libvirt</short>
-  <description>The libvirt zone for virtual networks. Used by libvirt for NAT and routed virtual networks.</description>
-</zone>
-EOFXML
-
-# ============================================================
-# SYSTEMD SERVICES (MODULAR DAEMONS)
-# ============================================================
-
-# virtqemud - QEMU/KVM hypervisor daemon
-cat > /etc/systemd/system/virtqemud.service << 'EOFSVC'
-[Unit]
-Description=Virtualization QEMU daemon
-Requires=virtlogd.socket
-Requires=virtlockd.socket
-After=network.target
-After=dbus.service
-After=local-fs.target
-Documentation=man:virtqemud(8)
-
-[Service]
-Type=notify
-TimeoutStartSec=60
-ExecStart=/usr/sbin/virtqemud
-ExecReload=/bin/kill -HUP $MAINPID
-Restart=on-failure
-RestartSec=5
-KillMode=process
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# virtnetworkd - Virtual network daemon
-cat > /etc/systemd/system/virtnetworkd.service << 'EOFSVC'
-[Unit]
-Description=Virtualization Network daemon
-After=network.target
-After=dbus.service
-After=firewalld.service
-Documentation=man:virtnetworkd(8)
-
-[Service]
-Type=notify
-TimeoutStartSec=60
-ExecStart=/usr/sbin/virtnetworkd
-ExecReload=/bin/kill -HUP $MAINPID
-Restart=on-failure
-RestartSec=5
-KillMode=process
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# virtlockd - Lock manager service
-cat > /etc/systemd/system/virtlockd.service << 'EOFSVC'
-[Unit]
-Description=Virtual machine lock manager
-Requires=virtlockd.socket
-Before=virtqemud.service
-Documentation=man:virtlockd(8)
-
-[Service]
-Type=notify
-ExecStart=/usr/sbin/virtlockd
-ExecReload=/bin/kill -USR1 $MAINPID
-Restart=on-failure
-
-[Install]
-Also=virtlockd.socket
-EOFSVC
-
-# virtlockd socket
-cat > /etc/systemd/system/virtlockd.socket << 'EOFSVC'
-[Unit]
-Description=Virtual machine lock manager socket
-Before=virtqemud.service
-
-[Socket]
-ListenStream=/var/run/libvirt/virtlockd-sock
-ListenStream=/var/run/libvirt/virtlockd-admin-sock
-
-[Install]
-WantedBy=sockets.target
-EOFSVC
-
-# virtlogd - Log manager service
-cat > /etc/systemd/system/virtlogd.service << 'EOFSVC'
-[Unit]
-Description=Virtual machine log manager
-Requires=virtlogd.socket
-Before=virtqemud.service
-Documentation=man:virtlogd(8)
-
-[Service]
-Type=notify
-ExecStart=/usr/sbin/virtlogd
-ExecReload=/bin/kill -USR1 $MAINPID
-Restart=on-failure
-
-[Install]
-Also=virtlogd.socket
-EOFSVC
-
-# virtlogd socket
-cat > /etc/systemd/system/virtlogd.socket << 'EOFSVC'
-[Unit]
-Description=Virtual machine log manager socket
-Before=virtqemud.service
-
-[Socket]
-ListenStream=/var/run/libvirt/virtlogd-sock
-ListenStream=/var/run/libvirt/virtlogd-admin-sock
-
-[Install]
-WantedBy=sockets.target
-EOFSVC
-
-# ============================================================
-# REMOVE OLD LIBVIRTD SERVICE (we use modular daemons)
-# ============================================================
-rm -f /etc/systemd/system/libvirtd.service 2>/dev/null || true
-
-# ============================================================
-# POLKIT RULES
-# ============================================================
+ln -sf /opt/hud/bin/virsh /usr/bin/virsh 2>/dev/null || true
+ln -sf /opt/hud/bin/virt-host-validate /usr/bin/virt-host-validate 2>/dev/null || true
+ln -sf /opt/hud/sbin/libvirtd /usr/sbin/libvirtd 2>/dev/null || true
+ln -sf /opt/hud/sbin/virtqemud /usr/sbin/virtqemud 2>/dev/null || true
+printf '[Unit]\nDescription=Virtualization daemon\nRequires=virtlogd.socket\nRequires=virtlockd.socket\nBefore=libvirt-guests.service\nAfter=network.target\nAfter=dbus.service\nAfter=apparmor.service\nAfter=remote-fs.target\nDocumentation=man:libvirtd(8)\nDocumentation=https://libvirt.org\n\n[Service]\nType=notify\nEnvironment=LIBVIRTD_ARGS="--timeout 120"\nEnvironmentFile=-/etc/sysconfig/libvirtd\nExecStart=/opt/hud/sbin/libvirtd $LIBVIRTD_ARGS\nExecReload=/bin/kill -HUP $MAINPID\nRestart=on-failure\nKillMode=process\n\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/libvirtd.service
+printf '[Unit]\nDescription=Virtual machine lock manager\nRequires=virtlockd.socket\nBefore=libvirtd.service\nDocumentation=man:virtlockd(8)\nDocumentation=https://libvirt.org\n\n[Service]\nType=notify\nExecStart=/opt/hud/sbin/virtlockd\nExecReload=/bin/kill -USR1 $MAINPID\nRestart=on-failure\n\n[Install]\nAlso=virtlockd.socket\n' > /etc/systemd/system/virtlockd.service
+printf '[Unit]\nDescription=Virtual machine lock manager socket\nBefore=libvirtd.service\n\n[Socket]\nListenStream=/var/run/libvirt/virtlockd-sock\nListenStream=/var/run/libvirt/virtlockd-admin-sock\n\n[Install]\nWantedBy=sockets.target\n' > /etc/systemd/system/virtlockd.socket
+printf '[Unit]\nDescription=Virtual machine log manager\nRequires=virtlogd.socket\nBefore=libvirtd.service\nDocumentation=man:virtlogd(8)\nDocumentation=https://libvirt.org\n\n[Service]\nType=notify\nExecStart=/opt/hud/sbin/virtlogd\nExecReload=/bin/kill -USR1 $MAINPID\nRestart=on-failure\n\n[Install]\nAlso=virtlogd.socket\n' > /etc/systemd/system/virtlogd.service
+printf '[Unit]\nDescription=Virtual machine log manager socket\nBefore=libvirtd.service\n\n[Socket]\nListenStream=/var/run/libvirt/virtlogd-sock\nListenStream=/var/run/libvirt/virtlogd-admin-sock\n\n[Install]\nWantedBy=sockets.target\n' > /etc/systemd/system/virtlogd.socket
 install -vdm755 /usr/share/polkit-1/rules.d
-cat > /usr/share/polkit-1/rules.d/org.libvirt.unix.manager.rules << 'EOFRULE'
-polkit.addRule(function(action, subject) {
-    if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("libvirt")) {
-        return polkit.Result.YES;
-    }
-});
-EOFRULE
-
-# ============================================================
-# ENABLE AND START SERVICES
-# ============================================================
+printf 'polkit.addRule(function(action, subject) {\n    if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("libvirt")) {\n        return polkit.Result.YES;\n    }\n});\n' > /usr/share/polkit-1/rules.d/org.libvirt.unix.manager.rules
 systemctl daemon-reload
 systemctl enable virtlockd.socket
 systemctl enable virtlogd.socket
-systemctl enable virtqemud.service
-systemctl enable virtnetworkd.service
+systemctl enable libvirtd.service
 systemctl start virtlockd.socket || true
 systemctl start virtlogd.socket || true
-systemctl start virtqemud.service || true
-systemctl start virtnetworkd.service || true
-
-echo ""
-echo "============================================"
-echo "libvirt 10.10.0 installed successfully"
-echo "============================================"
-echo ""
-echo "Commands:"
-echo "  virsh list --all          - List all VMs"
-echo "  virsh net-list --all      - List all networks"
-echo "  virt-host-validate qemu   - Validate host for QEMU/KVM"
-echo ""
-echo "Services:"
-echo "  systemctl status virtqemud"
-echo "  systemctl status virtnetworkd"
-echo ""
-echo "Add users to libvirt group:"
-echo "  usermod -aG libvirt <username>"
-echo ""
-echo "Start default network (requires dnsmasq):"
-echo "  virsh net-start default"
-echo ""
+systemctl start libvirtd.service || true
+echo "libvirt 10.10.0 installed"
+echo "Commands: virsh, virt-host-validate"
+echo "Service: systemctl status libvirtd"
+echo "Add users to libvirt group: usermod -aG libvirt username"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/libvirt-10.10.0.huddef</code> (16 added, 313 removed)</summary>

```diff
--- pool/main/l/libvirt/libvirt-10.10.0.huddef
+++ sources/definitions/old/packages/libvirt-10.10.0.huddef
@@ -1,15 +1,4 @@
 # HUD Package Definition - libvirt 10.10.0
-# Virtualization API for managing QEMU/KVM hypervisors
-# Uses modular daemon architecture (virtqemud, virtnetworkd, etc.)
-# Reference: https://libvirt.org/
-#
-# FIXES APPLIED:
-# - Modular daemons (virtqemud, virtnetworkd) instead of monolithic libvirtd
-# - Socket config files for daemon-created sockets (not systemd socket activation)
-# - nftables firewall backend for compatibility with firewalld
-# - Proper systemd services with timeouts
-# - Copies missing binaries (virsh, virt-host-validate, virtqemud, virtnetworkd)
-# - Creates firewalld libvirt zone
-# - Polkit rules for libvirt group
+# Auto-generated for oVirt infrastructure
 
 Package: libvirt
@@ -17,313 +6,27 @@
 Architecture: x86_64
 Section: virtualization
-Depends: qemu, python3, glib, libxml2, yajl, libpciaccess, numactl, polkit, dbus, libnl, gnutls, libgcrypt, curl, libssh2, nftables, dnsmasq, dmidecode
-Description: Virtualization API library for managing hypervisors (QEMU/KVM)
-Source: https://download.libvirt.org/libvirt-10.10.0.tar.xz
+Depends: glib2,libxml2,python3,qemu,gnutls,libssh2,cyrus-sasl,polkit,dbus,yajl
+Description: The virtualization API
+Source: https://libvirt.org/sources/libvirt-10.10.0.tar.xz
+Service: libvirtd
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share:${XDG_DATA_DIRS}"
-mkdir -p build
-cd build
-meson setup ..                              \
-      --prefix=/opt/hud                     \
-      --sysconfdir=/etc                     \
-      --localstatedir=/var                  \
-      --buildtype=release                   \
-      -D system=true                        \
-      -D driver_qemu=enabled                \
-      -D driver_libvirtd=enabled            \
-      -D driver_remote=enabled              \
-      -D driver_network=enabled             \
-      -D driver_interface=enabled           \
-      -D driver_secrets=enabled             \
-      -D secdriver_apparmor=disabled        \
-      -D secdriver_selinux=disabled         \
-      -D apparmor_profiles=disabled         \
-      -D selinux=disabled                   \
-      -D firewalld=disabled                 \
-      -D wireshark_dissector=disabled       \
-      -D storage_iscsi=disabled             \
-      -D storage_iscsi_direct=disabled      \
-      -D storage_scsi=enabled               \
-      -D storage_mpath=disabled             \
-      -D storage_gluster=disabled           \
-      -D storage_rbd=disabled               \
-      -D storage_zfs=disabled               \
-      -D glusterfs=disabled                 \
-      -D openwsman=disabled                 \
-      -D libiscsi=disabled                  \
-      -D sanlock=disabled                   \
-      -D libssh=disabled                    \
-      -D libssh2=enabled                    \
-      -D audit=disabled                     \
-      -D dtrace=disabled                    \
-      -D numad=disabled                     \
-      -D numactl=enabled                    \
-      -D netcf=disabled                     \
-      -D fuse=disabled                      \
-      -D nbdkit=disabled                    \
-      -D nss=disabled                       \
-      -D bash_completion=disabled           \
-      -D tests=disabled                     \
-      -D docs=disabled
+meson setup build --prefix=/opt/hud -Dsystem=true -Ddriver_qemu=enabled -Ddriver_libvirtd=enabled
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share:${XDG_DATA_DIRS}"
-cd build
-ninja
+ninja -C build
 
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
-# Ensure key binaries are copied to standard locations
-mkdir -p $DESTDIR/usr/bin $DESTDIR/usr/sbin
-cp -f tools/virsh $DESTDIR/usr/bin/virsh 2>/dev/null || true
-cp -f tools/virt-host-validate $DESTDIR/usr/bin/virt-host-validate 2>/dev/null || true
-cp -f src/virtqemud $DESTDIR/usr/sbin/virtqemud 2>/dev/null || true
-cp -f src/virtnetworkd $DESTDIR/usr/sbin/virtnetworkd 2>/dev/null || true
-chmod +x $DESTDIR/usr/bin/virsh $DESTDIR/usr/bin/virt-host-validate 2>/dev/null || true
-chmod +x $DESTDIR/usr/sbin/virtqemud $DESTDIR/usr/sbin/virtnetworkd 2>/dev/null || true
+DESTDIR=$DESTDIR ninja -C build install
 
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
+echo "libvirt 10.10.0 installed to /opt/hud"
 
-# Create directories
-install -vdm755 /etc/libvirt
-install -vdm755 /etc/libvirt/qemu
-install -vdm755 /etc/libvirt/qemu/networks
-install -vdm755 /var/lib/libvirt
-install -vdm755 /var/lib/libvirt/images
-install -vdm755 /var/lib/libvirt/qemu
-install -vdm755 /var/log/libvirt
-install -vdm755 /var/run/libvirt
-install -vdm755 /var/run/libvirt/qemu
+[prerm]
+# Stop service if running
+systemctl stop hud-libvirtd 2>/dev/null || true
+systemctl disable hud-libvirtd 2>/dev/null || true
 
-# Create groups and users
-groupadd -fg 36 kvm 2>/dev/null || true
-groupadd -fg 27 libvirt 2>/dev/null || true
-useradd -c "Libvirt User" -d /var/lib/libvirt -g libvirt -s /bin/false -u 27 libvirt 2>/dev/null || true
-chown -R libvirt:libvirt /var/lib/libvirt 2>/dev/null || true
-chown -R libvirt:libvirt /var/log/libvirt 2>/dev/null || true
-
-# Ensure binaries are in place (fallback to build directory)
-test -f /usr/bin/virsh || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/tools/virsh /usr/bin/virsh 2>/dev/null || true
-test -f /usr/bin/virt-host-validate || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/tools/virt-host-validate /usr/bin/virt-host-validate 2>/dev/null || true
-test -f /usr/sbin/virtqemud || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/src/virtqemud /usr/sbin/virtqemud 2>/dev/null || true
-test -f /usr/sbin/virtnetworkd || cp /var/hud-build/staging/libvirt-*/src/libvirt-*/build/src/virtnetworkd /usr/sbin/virtnetworkd 2>/dev/null || true
-chmod +x /usr/bin/virsh /usr/bin/virt-host-validate /usr/sbin/virtqemud /usr/sbin/virtnetworkd 2>/dev/null || true
-
-# ============================================================
-# DAEMON SOCKET CONFIGURATION (CRITICAL FOR SOCKET CREATION)
-# ============================================================
-# These config files tell the daemons to create their own sockets
-# instead of relying on systemd socket activation
-
-cat > /etc/libvirt/virtqemud.conf << 'EOFCONF'
-# virtqemud socket configuration
-# Daemon creates its own sockets (not systemd socket activation)
-unix_sock_group = "libvirt"
-unix_sock_ro_perms = "0777"
-unix_sock_rw_perms = "0770"
-unix_sock_admin_perms = "0700"
-unix_sock_dir = "/var/run/libvirt"
-EOFCONF
-
-cat > /etc/libvirt/virtnetworkd.conf << 'EOFCONF'
-# virtnetworkd socket configuration
-unix_sock_group = "libvirt"
-unix_sock_ro_perms = "0777"
-unix_sock_rw_perms = "0770"
-unix_sock_admin_perms = "0700"
-unix_sock_dir = "/var/run/libvirt"
-EOFCONF
-
-# Configure network to use nftables backend (works with firewalld)
-cat > /etc/libvirt/network.conf << 'EOFCONF'
-# Network driver configuration
-# Use nftables backend for firewalld compatibility
-firewall_backend = "nftables"
-EOFCONF
-
-# ============================================================
-# FIREWALLD LIBVIRT ZONE
-# ============================================================
-install -vdm755 /etc/firewalld/zones
-cat > /etc/firewalld/zones/libvirt.xml << 'EOFXML'
-<?xml version="1.0" encoding="utf-8"?>
-<zone target="ACCEPT">
-  <short>libvirt</short>
-  <description>The libvirt zone for virtual networks. Used by libvirt for NAT and routed virtual networks.</description>
-</zone>
-EOFXML
-
-# ============================================================
-# SYSTEMD SERVICES (MODULAR DAEMONS)
-# ============================================================
-
-# virtqemud - QEMU/KVM hypervisor daemon
-cat > /etc/systemd/system/virtqemud.service << 'EOFSVC'
-[Unit]
-Description=Virtualization QEMU daemon
-Requires=virtlogd.socket
-Requires=virtlockd.socket
-After=network.target
-After=dbus.service
-After=local-fs.target
-Documentation=man:virtqemud(8)
-
-[Service]
-Type=notify
-TimeoutStartSec=60
-ExecStart=/usr/sbin/virtqemud
-ExecReload=/bin/kill -HUP $MAINPID
-Restart=on-failure
-RestartSec=5
-KillMode=process
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# virtnetworkd - Virtual network daemon
-cat > /etc/systemd/system/virtnetworkd.service << 'EOFSVC'
-[Unit]
-Description=Virtualization Network daemon
-After=network.target
-After=dbus.service
-After=firewalld.service
-Documentation=man:virtnetworkd(8)
-
-[Service]
-Type=notify
-TimeoutStartSec=60
-ExecStart=/usr/sbin/virtnetworkd
-ExecReload=/bin/kill -HUP $MAINPID
-Restart=on-failure
-RestartSec=5
-KillMode=process
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# virtlockd - Lock manager service
-cat > /etc/systemd/system/virtlockd.service << 'EOFSVC'
-[Unit]
-Description=Virtual machine lock manager
-Requires=virtlockd.socket
-Before=virtqemud.service
-Documentation=man:virtlockd(8)
-
-[Service]
-Type=notify
-ExecStart=/usr/sbin/virtlockd
-ExecReload=/bin/kill -USR1 $MAINPID
-Restart=on-failure
-
-[Install]
-Also=virtlockd.socket
-EOFSVC
-
-# virtlockd socket
-cat > /etc/systemd/system/virtlockd.socket << 'EOFSVC'
-[Unit]
-Description=Virtual machine lock manager socket
-Before=virtqemud.service
-
-[Socket]
-ListenStream=/var/run/libvirt/virtlockd-sock
-ListenStream=/var/run/libvirt/virtlockd-admin-sock
-
-[Install]
-WantedBy=sockets.target
-EOFSVC
-
-# virtlogd - Log manager service
-cat > /etc/systemd/system/virtlogd.service << 'EOFSVC'
-[Unit]
-Description=Virtual machine log manager
-Requires=virtlogd.socket
-Before=virtqemud.service
-Documentation=man:virtlogd(8)
-
-[Service]
-Type=notify
-ExecStart=/usr/sbin/virtlogd
-ExecReload=/bin/kill -USR1 $MAINPID
-Restart=on-failure
-
-[Install]
-Also=virtlogd.socket
-EOFSVC
-
-# virtlogd socket
-cat > /etc/systemd/system/virtlogd.socket << 'EOFSVC'
-[Unit]
-Description=Virtual machine log manager socket
-Before=virtqemud.service
-
-[Socket]
-ListenStream=/var/run/libvirt/virtlogd-sock
-ListenStream=/var/run/libvirt/virtlogd-admin-sock
-
-[Install]
-WantedBy=sockets.target
-EOFSVC
-
-# ============================================================
-# REMOVE OLD LIBVIRTD SERVICE (we use modular daemons)
-# ============================================================
-rm -f /etc/systemd/system/libvirtd.service 2>/dev/null || true
-
-# ============================================================
-# POLKIT RULES
-# ============================================================
-install -vdm755 /usr/share/polkit-1/rules.d
-cat > /usr/share/polkit-1/rules.d/org.libvirt.unix.manager.rules << 'EOFRULE'
-polkit.addRule(function(action, subject) {
-    if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("libvirt")) {
-        return polkit.Result.YES;
-    }
-});
-EOFRULE
-
-# ============================================================
-# ENABLE AND START SERVICES
-# ============================================================
-systemctl daemon-reload
-systemctl enable virtlockd.socket
-systemctl enable virtlogd.socket
-systemctl enable virtqemud.service
-systemctl enable virtnetworkd.service
-systemctl start virtlockd.socket || true
-systemctl start virtlogd.socket || true
-systemctl start virtqemud.service || true
-systemctl start virtnetworkd.service || true
-
-echo ""
-echo "============================================"
-echo "libvirt 10.10.0 installed successfully"
-echo "============================================"
-echo ""
-echo "Commands:"
-echo "  virsh list --all          - List all VMs"
-echo "  virsh net-list --all      - List all networks"
-echo "  virt-host-validate qemu   - Validate host for QEMU/KVM"
-echo ""
-echo "Services:"
-echo "  systemctl status virtqemud"
-echo "  systemctl status virtnetworkd"
-echo ""
-echo "Add users to libvirt group:"
-echo "  usermod -aG libvirt <username>"
-echo ""
-echo "Start default network (requires dnsmasq):"
-echo "  virsh net-start default"
-echo ""
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libvirt-python`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/libvirt/libvirt-python-10.10.0.huddef` | 10.10.0 | `3037d08c29e8` | `79ac2bf862bf` | alt |
| `sources/definitions/libvirt_9feb_2026/libvirt-python-10.10.0.huddef` | 10.10.0 | `e88cdc4e0cfd` | `156fdcd27f01` | alt |

Diffs below are taken from the first variant, `sources/definitions/libvirt/libvirt-python-10.10.0.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/libvirt_9feb_2026/libvirt-python-10.10.0.huddef</code> (17 added, 15 removed)</summary>

```diff
--- sources/definitions/libvirt/libvirt-python-10.10.0.huddef
+++ sources/definitions/libvirt_9feb_2026/libvirt-python-10.10.0.huddef
@@ -1,10 +1,11 @@
 # HUD Package Definition - libvirt-python 10.10.0
-# Python bindings for libvirt virtualization API
-# Used by VDSM and other Python-based virtualization management tools
+# Python bindings for libvirt
+# Required by VDSM and other management tools
+# Reference: https://libvirt.org/
 
 Package: libvirt-python
 Version: 10.10.0
 Architecture: x86_64
-Section: python
+Section: virtualization
 Depends: libvirt, python3
 Description: Python bindings for libvirt virtualization API
@@ -13,32 +14,33 @@
 [configure]
 export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 export CFLAGS="-I/opt/hud/include"
 export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-echo "libvirt-python uses setup.py, no configure step needed"
+# No configure step - uses setup.py
 
 [build]
 export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
 python3 setup.py build
 
 [install]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-python3 setup.py install --root=$DESTDIR --prefix=/opt/hud --optimize=1
+python3 setup.py install --root=$DESTDIR --prefix=/opt/hud
 
 [postinst]
 ldconfig
+
+# Test import
+python3 -c "import libvirt; print('libvirt-python version:', libvirt.getVersion())" 2>/dev/null || true
+
+echo ""
 echo "libvirt-python 10.10.0 installed"
 echo ""
-echo "Python usage:"
+echo "Test: python3 -c 'import libvirt; print(libvirt.getVersion())'"
+echo ""
+echo "Example usage:"
 echo "  import libvirt"
 echo "  conn = libvirt.open('qemu:///system')"
-echo "  domains = conn.listAllDomains()"
-echo ""
-echo "Test with: python3 -c \"import libvirt; print(libvirt.getVersion())\""
+echo "  print(conn.listAllDomains())"
```

</details>


### `libvorbis`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libvorbis/libvorbis-1.3.7.huddef` | 1.3.7 | `a9541f5029ea` | `5d4360b35957` | **POOL** |
| `sources/definitions/old/packages/libvorbis-1.3.7.huddef` | 1.3.7 | `0031f502b89f` | `4ae06b01cde0` | alt |
| `sources/definitions/old/updated-packages/libvorbis-1.3.7.huddef` | 1.3.7 | `a9541f5029ea` | `5d4360b35957` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/libvorbis-1.3.7.huddef</code> (13 added, 8 removed)</summary>

```diff
--- pool/main/l/libvorbis/libvorbis-1.3.7.huddef
+++ sources/definitions/old/packages/libvorbis-1.3.7.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - libvorbis 1.3.7
-# General purpose audio and music encoding format
+# Auto-generated for oVirt infrastructure
 
 Package: libvorbis
@@ -6,10 +6,10 @@
 Architecture: x86_64
 Section: libraries
-Depends: libogg
-Description: General purpose audio and music encoding format (patent free)
+Depends: tl-installer,libogg,doxygen
+Description: libvorbis-1.3.7
 Source: https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz
 
 [configure]
-./configure --prefix=/opt/hud --disable-static --with-ogg-prefix=/opt/hud
+./configure --prefix=/opt/hud
 
 [build]
@@ -17,9 +17,14 @@
 
 [install]
-make DESTDIR=$DESTDIR install
-install -v -dm755 $DESTDIR/opt/hud/share/doc/libvorbis-1.3.7
-install -v -m644 doc/Vorbis* $DESTDIR/opt/hud/share/doc/libvorbis-1.3.7
+make install &&
+install -v -m644 doc/Vorbis* /usr/share/doc/libvorbis-1.3.7
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libvorbis 1.3.7 installed to /opt/hud"
+echo "libvorbis 1.3.7 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libxcb`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libxcb/libxcb-1.17.0.huddef` | 1.17.0 | `77ddbde98ad0` | `772680ebbadc` | **POOL** |
| `sources/definitions/old/0/libxcb-1.17.0.huddef` | 1.17.0 | `2da36c1f1818` | `bcbd1269cc38` | alt |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/libxcb-1.17.0.huddef` | 1.17.0 | `77ddbde98ad0` | `772680ebbadc` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libxcb-1.17.0.huddef</code> (6 added, 21 removed)</summary>

```diff
--- pool/main/l/libxcb/libxcb-1.17.0.huddef
+++ sources/definitions/old/0/libxcb-1.17.0.huddef
@@ -1,33 +1,18 @@
 # HUD Package Definition - libxcb 1.17.0
-# X Protocol C-language Binding
-# C interface to the X Window System protocol
-# Fixed: Added util-macros dependency and proper PKG_CONFIG_PATH
-
+# Interface to X Window System protocol
 Package: libxcb
 Version: 1.17.0
 Architecture: x86_64
 Section: xorg
-Depends: xcb-proto, libXau, libXdmcp, util-macros
-Description: C interface to the X Window System protocol replacing Xlib
+Depends: libXau,libXdmcp,xcb-proto
+Description: Interface to the X Window System protocol replacing Xlib
 Source: https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz
-
 [configure]
-# Ensure pkg-config can find all dependencies
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/opt/hud/share/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
-export ACLOCAL_PATH="/opt/hud/share/aclocal:${ACLOCAL_PATH}"
-
-./configure --prefix=/opt/hud    \
-            --sysconfdir=/etc    \
-            --localstatedir=/var \
-            --disable-static     \
-            --without-doxygen
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static --without-doxygen --docdir=/opt/hud/share/doc/libxcb-1.17.0
 [build]
-make -j$(nproc)
-
+LC_ALL=en_US.UTF-8 make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ libxcb 1.17.0 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libxml2`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libxml2/libxml2-2.14.5.huddef` | 2.14.5 | `ab93302acc36` | `5f0e46c10467` | **POOL** |
| `sources/definitions/old/0/libxml2-2.14.5.huddef` | 2.14.5 | `610047664581` | `bccc5760d455` | alt |
| `sources/definitions/old/packages/libxml2-2.14.5.huddef` | 2.14.5 | `886151f0e02b` | `361bb1263f65` | alt |
| `sources/definitions/old/updated-packages/libxml2-2.14.5.huddef` | 2.14.5 | `ab93302acc36` | `5f0e46c10467` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libxml2-2.14.5.huddef</code> (7 added, 31 removed)</summary>

```diff
--- pool/main/l/libxml2/libxml2-2.14.5.huddef
+++ sources/definitions/old/0/libxml2-2.14.5.huddef
@@ -1,42 +1,18 @@
 # HUD Package Definition - libxml2 2.14.5
 # XML parsing library
-
 Package: libxml2
 Version: 2.14.5
 Architecture: x86_64
 Section: libraries
-Depends: icu
-Description: libxml2 - XML parsing library with ICU support
+Depends: zlib,xz,icu,python3
+Description: XML C parser and toolkit
 Source: https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz
-
 [configure]
-./configure --prefix=/opt/hud           \
-            --sysconfdir=/opt/hud/etc   \
-            --disable-static            \
-            --with-history              \
-            --with-icu                  \
-            --docdir=/opt/hud/share/doc/libxml2-2.14.5
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --disable-static --with-history --with-icu PYTHON=/usr/bin/python3
 [build]
-make -j$(nproc)
-
+make
 [install]
-make DESTDIR=${DESTDIR} install
-
-# Remove libtool archive to prevent unnecessary ICU linking
-rm -vf ${DESTDIR}/opt/hud/lib/libxml2.la
-
-# Fix xml2-config to prevent unnecessary ICU linking
-if [ -f ${DESTDIR}/opt/hud/bin/xml2-config ]; then
-    sed '/libs=/s/xml2.*/xml2"/' -i ${DESTDIR}/opt/hud/bin/xml2-config
-fi
-
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
-echo "libxml2 2.14.5 installed to /opt/hud"
-
-[prerm]
-# Nothing to do
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libxml2 2.14.5 installed to /opt/hud"
+/sbin/ldconfig
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/libxml2-2.14.5.huddef</code> (6 added, 19 removed)</summary>

```diff
--- pool/main/l/libxml2/libxml2-2.14.5.huddef
+++ sources/definitions/old/packages/libxml2-2.14.5.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - libxml2 2.14.5
-# XML parsing library
+# Auto-generated for oVirt infrastructure
 
 Package: libxml2
@@ -6,15 +6,10 @@
 Architecture: x86_64
 Section: libraries
-Depends: icu
-Description: libxml2 - XML parsing library with ICU support
+Depends: icu,valgrind
+Description: libxml2-2.14.5
 Source: https://download.gnome.org/sources/libxml2/2.14/libxml2-2.14.5.tar.xz
 
 [configure]
-./configure --prefix=/opt/hud           \
-            --sysconfdir=/opt/hud/etc   \
-            --disable-static            \
-            --with-history              \
-            --with-icu                  \
-            --docdir=/opt/hud/share/doc/libxml2-2.14.5
+./configure --prefix=/opt/hud --with-history --with-icu --with-python=/opt/hud/bin/python3
 
 [build]
@@ -22,13 +17,5 @@
 
 [install]
-make DESTDIR=${DESTDIR} install
-
-# Remove libtool archive to prevent unnecessary ICU linking
-rm -vf ${DESTDIR}/opt/hud/lib/libxml2.la
-
-# Fix xml2-config to prevent unnecessary ICU linking
-if [ -f ${DESTDIR}/opt/hud/bin/xml2-config ]; then
-    sed '/libs=/s/xml2.*/xml2"/' -i ${DESTDIR}/opt/hud/bin/xml2-config
-fi
+make install
 
 [postinst]
@@ -37,5 +24,5 @@
 
 [prerm]
-# Nothing to do
+# Stop service if running
 
 [postrm]
```

</details>


### `libxslt`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libxslt/libxslt-1.1.43.huddef` | 1.1.43 | `058f155bda4f` | `94b67fb64548` | **POOL** |
| `sources/definitions/old/0/libxslt-1.1.43.huddef` | 1.1.43 | `708e8d58b4ab` | `26c5f6111888` | alt |
| `sources/definitions/old/packages/libxslt-1.1.43.huddef` | 1.1.43 | `058f155bda4f` | `94b67fb64548` | **= POOL** |
| `sources/definitions/old/updated-packages/libxslt-1.1.43.huddef` | 1.1.43 | `058f155bda4f` | `94b67fb64548` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/libxslt-1.1.43.huddef</code> (8 added, 19 removed)</summary>

```diff
--- pool/main/l/libxslt/libxslt-1.1.43.huddef
+++ sources/definitions/old/0/libxslt-1.1.43.huddef
@@ -1,29 +1,18 @@
 # HUD Package Definition - libxslt 1.1.43
-# Auto-generated for oVirt infrastructure
-
+# XSLT processing library
 Package: libxslt
 Version: 1.1.43
 Architecture: x86_64
 Section: libraries
-Depends: libxml2,docbook,libgcrypt,docbook-xsl
-Description: libxslt-1.1.43
+Depends: libxml2,libgcrypt
+Description: XML stylesheet transformation library
 Source: https://download.gnome.org/sources/libxslt/1.1/libxslt-1.1.43.tar.xz
-
 [configure]
-./configure --prefix=/opt/hud
-
+./configure --prefix=/opt/hud --sysconfdir=/etc --disable-static --without-python
 [build]
-make -j$(nproc)
-
+make
 [install]
-make install
-
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
-echo "libxslt 1.1.43 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ libxslt 1.1.43 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `linux-pam`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/linux-pam/linux-pam-1.7.1.huddef` | 1.7.1 | `ac4c824afbf2` | `c43ed8db8bd9` | **POOL** |
| `sources/definitions/old/1 Feb 2026/linux-pam-1.7.1.huddef` | 1.7.1 | `442f3c23a7fb` | `102d4eead723` | alt |
| `sources/definitions/old/linux-pam-1.7.1.huddef` | 1.7.1 | `442f3c23a7fb` | `102d4eead723` | alt |
| `sources/definitions/old/packages/linux-pam-1.7.0.huddef` | 1.7.0 | `4c139757ff8a` | `f999e5e2c4b2` | alt |
| `sources/definitions/old/packages/linux-pam-1.7.1.huddef` | 1.7.1 | `bc16378bee3d` | `c78973228032` | alt |
| `sources/definitions/old/updated-packages/linux-pam-1.7.1.huddef` | 1.7.1 | `ac4c824afbf2` | `c43ed8db8bd9` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/linux-pam-1.7.1.huddef</code> (29 added, 22 removed)</summary>

```diff
--- pool/main/l/linux-pam/linux-pam-1.7.1.huddef
+++ sources/definitions/old/1 Feb 2026/linux-pam-1.7.1.huddef
@@ -1,4 +1,6 @@
-# HUD Package Definition - linux-pam 1.7.1
-# Based on BLFS 12.4 documentation
+# HUD Package Definition - Linux-PAM 1.7.1
+# Pluggable Authentication Modules
+# Authentication framework for Linux systems
+# Fixed: Disabled documentation to avoid DocBook 5.0 dependency
 
 Package: linux-pam
@@ -11,27 +13,32 @@
 
 [configure]
-# Create build directory and run meson
-mkdir -p build &&
-cd build &&
-meson setup ..        \
-  --prefix=/opt/hud   \
-  --buildtype=release \
-  -D docdir=/opt/hud/share/doc/Linux-PAM-1.7.1
+mkdir -p build
+cd build
+
+# Disable documentation generation to avoid DocBook 5.0 XML schema dependency
+# Documentation can be installed separately from pre-built tarball
+meson setup ..                \
+    --prefix=/opt/hud         \
+    --buildtype=release       \
+    -D docs=disabled          \
+    -D docdir=/opt/hud/share/doc/Linux-PAM-1.7.1
 
 [build]
-cd build &&
+cd build
 ninja
 
 [install]
-cd build &&
-DESTDIR=$DESTDIR ninja install &&
-chmod -v 4755 $DESTDIR/opt/hud/sbin/unix_chkpwd
+cd build
+DESTDIR=$DESTDIR ninja install
+
+# Set proper permissions on unix_chkpwd
+chmod -v 4755 $DESTDIR/opt/hud/sbin/unix_chkpwd 2>/dev/null || true
 
 [postinst]
-ldconfig 2>/dev/null || true
+# Create PAM configuration directories
+install -v -m755 -d /etc/pam.d
+install -v -m755 -d /etc/security
 
 # Create basic PAM configuration files if they don't exist
-install -vdm755 /etc/pam.d
-
 if [ ! -f /etc/pam.d/system-account ]; then
 cat > /etc/pam.d/system-account << "EOF"
@@ -81,10 +88,10 @@
 fi
 
-echo "linux-pam 1.7.1 installed to /opt/hud"
-echo "NOTE: Shadow and Systemd should be reinstalled after installing Linux-PAM"
+# Fix permissions
+chmod -v 4755 /opt/hud/sbin/unix_chkpwd 2>/dev/null || true
 
-[prerm]
-# Do not remove PAM configuration files as system may become unusable
-
-[postrm]
 ldconfig 2>/dev/null || true
+echo "✓ Linux-PAM 1.7.1 installed to /opt/hud"
+echo "  Note: Documentation was not built. Install pre-built docs from:"
+echo "  https://anduin.linuxfromscratch.org/BLFS/Linux-PAM/Linux-PAM-1.7.1-docs.tar.xz"
+echo "  IMPORTANT: Reinstall Shadow and Systemd with PAM support!"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/linux-pam-1.7.0.huddef</code> (29 added, 76 removed)</summary>

```diff
--- pool/main/l/linux-pam/linux-pam-1.7.1.huddef
+++ sources/definitions/old/packages/linux-pam-1.7.0.huddef
@@ -1,90 +1,43 @@
-# HUD Package Definition - linux-pam 1.7.1
-# Based on BLFS 12.4 documentation
+# HUD Package Definition - linux-pam 1.7.0
+# Pluggable Authentication Modules
 
 Package: linux-pam
-Version: 1.7.1
+Version: 1.7.0
 Architecture: x86_64
 Section: security
 Depends:
-Description: Pluggable Authentication Modules for controlling how applications authenticate users
-Source: https://github.com/linux-pam/linux-pam/releases/download/v1.7.1/Linux-PAM-1.7.1.tar.xz
+Description: Pluggable Authentication Modules for Linux
+Source: https://github.com/linux-pam/linux-pam/releases/download/v1.7.0/Linux-PAM-1.7.0.tar.xz
 
 [configure]
-# Create build directory and run meson
-mkdir -p build &&
-cd build &&
-meson setup ..        \
-  --prefix=/opt/hud   \
-  --buildtype=release \
-  -D docdir=/opt/hud/share/doc/Linux-PAM-1.7.1
+./configure \
+    --prefix=/opt/hud \
+    --sysconfdir=/opt/hud/etc \
+    --libdir=/opt/hud/lib \
+    --enable-securedir=/opt/hud/lib/security \
+    --docdir=/opt/hud/share/doc/linux-pam-1.7.0 \
+    --disable-regenerate-docu
 
 [build]
-cd build &&
-ninja
+make -j$(nproc)
 
 [install]
-cd build &&
-DESTDIR=$DESTDIR ninja install &&
-chmod -v 4755 $DESTDIR/opt/hud/sbin/unix_chkpwd
+make DESTDIR=$DESTDIR install
+# Install PAM config files
+mkdir -p $DESTDIR/opt/hud/etc/pam.d
+cat > $DESTDIR/opt/hud/etc/pam.d/system-auth << 'SYSAUTH'
+auth      required  pam_unix.so
+account   required  pam_unix.so
+password  required  pam_unix.so sha512 shadow
+session   required  pam_unix.so
+SYSAUTH
+cat > $DESTDIR/opt/hud/etc/pam.d/other << 'OTHER'
+auth      required  pam_deny.so
+account   required  pam_deny.so
+password  required  pam_deny.so
+session   required  pam_deny.so
+OTHER
 
 [postinst]
 ldconfig 2>/dev/null || true
-
-# Create basic PAM configuration files if they don't exist
-install -vdm755 /etc/pam.d
-
-if [ ! -f /etc/pam.d/system-account ]; then
-cat > /etc/pam.d/system-account << "EOF"
-# Begin /etc/pam.d/system-account
-account   required    pam_unix.so
-# End /etc/pam.d/system-account
-EOF
-fi
-
-if [ ! -f /etc/pam.d/system-auth ]; then
-cat > /etc/pam.d/system-auth << "EOF"
-# Begin /etc/pam.d/system-auth
-auth      required    pam_unix.so
-# End /etc/pam.d/system-auth
-EOF
-fi
-
-if [ ! -f /etc/pam.d/system-session ]; then
-cat > /etc/pam.d/system-session << "EOF"
-# Begin /etc/pam.d/system-session
-session   required    pam_unix.so
-# End /etc/pam.d/system-session
-EOF
-fi
-
-if [ ! -f /etc/pam.d/system-password ]; then
-cat > /etc/pam.d/system-password << "EOF"
-# Begin /etc/pam.d/system-password
-password  required    pam_unix.so       yescrypt shadow try_first_pass
-# End /etc/pam.d/system-password
-EOF
-fi
-
-if [ ! -f /etc/pam.d/other ]; then
-cat > /etc/pam.d/other << "EOF"
-# Begin /etc/pam.d/other
-auth        required        pam_warn.so
-auth        required        pam_deny.so
-account     required        pam_warn.so
-account     required        pam_deny.so
-password    required        pam_warn.so
-password    required        pam_deny.so
-session     required        pam_warn.so
-session     required        pam_deny.so
-# End /etc/pam.d/other
-EOF
-fi
-
-echo "linux-pam 1.7.1 installed to /opt/hud"
-echo "NOTE: Shadow and Systemd should be reinstalled after installing Linux-PAM"
-
-[prerm]
-# Do not remove PAM configuration files as system may become unusable
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ linux-pam 1.7.0 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/linux-pam-1.7.1.huddef</code> (7 added, 68 removed)</summary>

```diff
--- pool/main/l/linux-pam/linux-pam-1.7.1.huddef
+++ sources/definitions/old/packages/linux-pam-1.7.1.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - linux-pam 1.7.1
-# Based on BLFS 12.4 documentation
+# Auto-generated for oVirt infrastructure
 
 Package: linux-pam
@@ -6,84 +6,23 @@
 Architecture: x86_64
 Section: security
-Depends:
-Description: Pluggable Authentication Modules for controlling how applications authenticate users
+Depends: libxslt,lynx,shadow,libpwquality,elogind,docbook5
+Description: Linux-PAM-1.7.1
 Source: https://github.com/linux-pam/linux-pam/releases/download/v1.7.1/Linux-PAM-1.7.1.tar.xz
 
 [configure]
-# Create build directory and run meson
-mkdir -p build &&
-cd build &&
-meson setup ..        \
-  --prefix=/opt/hud   \
-  --buildtype=release \
-  -D docdir=/opt/hud/share/doc/Linux-PAM-1.7.1
+./configure --prefix=/opt/hud
 
 [build]
-cd build &&
-ninja
+make -j$(nproc)
 
 [install]
-cd build &&
-DESTDIR=$DESTDIR ninja install &&
-chmod -v 4755 $DESTDIR/opt/hud/sbin/unix_chkpwd
+make install
 
 [postinst]
 ldconfig 2>/dev/null || true
-
-# Create basic PAM configuration files if they don't exist
-install -vdm755 /etc/pam.d
-
-if [ ! -f /etc/pam.d/system-account ]; then
-cat > /etc/pam.d/system-account << "EOF"
-# Begin /etc/pam.d/system-account
-account   required    pam_unix.so
-# End /etc/pam.d/system-account
-EOF
-fi
-
-if [ ! -f /etc/pam.d/system-auth ]; then
-cat > /etc/pam.d/system-auth << "EOF"
-# Begin /etc/pam.d/system-auth
-auth      required    pam_unix.so
-# End /etc/pam.d/system-auth
-EOF
-fi
-
-if [ ! -f /etc/pam.d/system-session ]; then
-cat > /etc/pam.d/system-session << "EOF"
-# Begin /etc/pam.d/system-session
-session   required    pam_unix.so
-# End /etc/pam.d/system-session
-EOF
-fi
-
-if [ ! -f /etc/pam.d/system-password ]; then
-cat > /etc/pam.d/system-password << "EOF"
-# Begin /etc/pam.d/system-password
-password  required    pam_unix.so       yescrypt shadow try_first_pass
-# End /etc/pam.d/system-password
-EOF
-fi
-
-if [ ! -f /etc/pam.d/other ]; then
-cat > /etc/pam.d/other << "EOF"
-# Begin /etc/pam.d/other
-auth        required        pam_warn.so
-auth        required        pam_deny.so
-account     required        pam_warn.so
-account     required        pam_deny.so
-password    required        pam_warn.so
-password    required        pam_deny.so
-session     required        pam_warn.so
-session     required        pam_deny.so
-# End /etc/pam.d/other
-EOF
-fi
-
 echo "linux-pam 1.7.1 installed to /opt/hud"
-echo "NOTE: Shadow and Systemd should be reinstalled after installing Linux-PAM"
 
 [prerm]
-# Do not remove PAM configuration files as system may become unusable
+# Stop service if running
 
 [postrm]
```

</details>


### `make-ca`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/m/make-ca/make-ca-1.16.1.huddef` | 1.16.1 | `7c64de9019c2` | `8b61e658b142` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/make-ca-1.16.1.huddef` | 1.16.1 | `c824978bfde0` | `d9064eec9247` | alt |
| `sources/definitions/old/packages/make-ca-1.16.1.huddef` | 1.16.1 | `b83962d618cc` | `ebeded2813fe` | alt |
| `sources/definitions/old/updated-packages/make-ca-1.16.1.huddef` | 1.16.1 | `7c64de9019c2` | `8b61e658b142` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/make-ca-1.16.1.huddef</code> (20 added, 18 removed)</summary>

```diff
--- pool/main/m/make-ca/make-ca-1.16.1.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/make-ca-1.16.1.huddef
@@ -1,4 +1,5 @@
 # HUD Package Definition - make-ca 1.16.1
-# Based on BLFS 12.4 documentation
+# Certificate Authority Management
+# Script to manage system CA certificates
 
 Package: make-ca
@@ -6,29 +7,30 @@
 Architecture: x86_64
 Section: security
-Depends: p11-kit
-Description: PKI certificate management tool that downloads and processes CA certificates for system trust store
-Source: https://github.com/lfs-book/make-ca/archive/v1.16.1/make-ca-1.16.1.tar.gz
+Depends: p11-kit, openssl
+Description: Script and configuration for managing Certificate Authorities (CA) in various formats
+Source: https://github.com/lfs-book/make-ca/releases/download/v1.16.1/make-ca-1.16.1.tar.xz
 
 [configure]
-# No configuration needed - make-ca is a shell script package
+# No configure needed - it's a script-based package
 
 [build]
-# No build step needed - make-ca is a shell script package
+# No build needed
 
 [install]
-make install DESTDIR=$DESTDIR &&
+make DESTDIR=$DESTDIR install
+
+# Install configuration
 install -vdm755 $DESTDIR/etc/ssl/local
 
 [postinst]
+# Create necessary directories
+install -vdm755 /etc/ssl/local
+install -vdm755 /etc/pki/tls/certs
+install -vdm755 /etc/pki/anchors
+
+# Run make-ca to set up initial certificates
+/opt/hud/sbin/make-ca -g 2>/dev/null || true
+
 ldconfig 2>/dev/null || true
-# Generate initial certificate store
-# Note: Requires network access - run manually if needed
-# /usr/sbin/make-ca -g
-echo "make-ca 1.16.1 installed to /opt/hud"
-echo "Run '/usr/sbin/make-ca -g' to download and generate certificate stores"
-
-[prerm]
-# No services to stop
-
-[postrm]
-# Certificate stores managed separately
+echo "✓ make-ca 1.16.1 installed to /opt/hud"
+echo "  Run '/opt/hud/sbin/make-ca -g' to update CA certificates"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/make-ca-1.16.1.huddef</code> (10 added, 14 removed)</summary>

```diff
--- pool/main/m/make-ca/make-ca-1.16.1.huddef
+++ sources/definitions/old/packages/make-ca-1.16.1.huddef
@@ -1,34 +1,30 @@
 # HUD Package Definition - make-ca 1.16.1
-# Based on BLFS 12.4 documentation
+# Auto-generated for oVirt infrastructure
 
 Package: make-ca
 Version: 1.16.1
 Architecture: x86_64
-Section: security
-Depends: p11-kit
-Description: PKI certificate management tool that downloads and processes CA certificates for system trust store
+Section: misc
+Depends: nss,wget,fcron,p11-kit,libtasn1
+Description: make-ca-1.16.1
 Source: https://github.com/lfs-book/make-ca/archive/v1.16.1/make-ca-1.16.1.tar.gz
 
 [configure]
-# No configuration needed - make-ca is a shell script package
+./configure --prefix=/opt/hud
 
 [build]
-# No build step needed - make-ca is a shell script package
+make -j$(nproc)
 
 [install]
-make install DESTDIR=$DESTDIR &&
-install -vdm755 $DESTDIR/etc/ssl/local
+make install &&
+install -vdm755 /etc/ssl/local
 
 [postinst]
 ldconfig 2>/dev/null || true
-# Generate initial certificate store
-# Note: Requires network access - run manually if needed
-# /usr/sbin/make-ca -g
 echo "make-ca 1.16.1 installed to /opt/hud"
-echo "Run '/usr/sbin/make-ca -g' to download and generate certificate stores"
 
 [prerm]
-# No services to stop
+# Stop service if running
 
 [postrm]
-# Certificate stores managed separately
+ldconfig 2>/dev/null || true
```

</details>


### `mesa`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/0/mesa-25.1.8.huddef` | 25.1.8 | `91d551dab46a` | `e7bf968db575` | alt |
| `sources/definitions/old/packages/mesa-25.1.8.huddef` | 25.1.8 | `6f36372e0a03` | `1b098f2c0ae6` | alt |
| `sources/definitions/old/updated-packages/mesa-25.1.8.huddef` | 25.1.8 | `6f36372e0a03` | `1b098f2c0ae6` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/0/mesa-25.1.8.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/mesa-25.1.8.huddef</code> (19 added, 23 removed)</summary>

```diff
--- sources/definitions/old/0/mesa-25.1.8.huddef
+++ sources/definitions/old/packages/mesa-25.1.8.huddef
@@ -1,33 +1,29 @@
 # HUD Package Definition - mesa 25.1.8
-# OpenGL compatible 3D graphics library
+# Auto-generated for oVirt infrastructure
+
 Package: mesa
 Version: 25.1.8
 Architecture: x86_64
 Section: graphics
-Depends: libdrm,libX11,libXext,libXfixes,libXxf86vm,libxcb,libxshmfence,wayland,wayland-protocols,libxml2,llvm,python3-mako,glslang
-Description: Open source implementation of OpenGL and Vulkan
+Depends: pyyaml,rust-bindgen,xorg7-lib,cbindgen,llvm,plasma-build,glslang,wayland-protocols,pciutils,libunwind,mesa-gallium-drivers,libva,gtk3,libdrm,libclc,vulkan-loader,ply,qemu,libgcrypt,make-ca,nettle,postlfs-firmware,libvdpau
+Description: Mesa-25.1.8
 Source: https://mesa.freedesktop.org/archive/mesa-25.1.8.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release \
-    -Dplatforms=x11,wayland \
-    -Dgallium-drivers=radeonsi,nouveau,virgl,svga,swrast,iris,crocus,zink \
-    -Dvulkan-drivers=amd,intel,intel_hasvk,swrast \
-    -Dglx=dri \
-    -Degl=enabled \
-    -Dgles1=enabled \
-    -Dgles2=enabled \
-    -Dshared-glapi=enabled \
-    -Dgbm=enabled \
-    -Dvalgrind=disabled \
-    ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ mesa 25.1.8 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "mesa 25.1.8 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `meson`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/m/meson/meson-1.8.3.huddef` | 1.8.3 | `38013df4e575` | `8f5a1766094e` | **POOL** |
| `sources/definitions/old/0/meson-1.8.3.huddef` | 1.8.3 | `3eb9ef328243` | `2d3d13c53503` | alt |
| `sources/definitions/old/packages/meson-1.6.1.huddef` | 1.6.1 | `22802f9d539c` | `b12a2be65003` | alt |
| `sources/definitions/old/updated-packages/meson-1.8.3.huddef` | 1.8.3 | `38013df4e575` | `8f5a1766094e` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/meson-1.8.3.huddef</code> (7 added, 8 removed)</summary>

```diff
--- pool/main/m/meson/meson-1.8.3.huddef
+++ sources/definitions/old/0/meson-1.8.3.huddef
@@ -1,20 +1,19 @@
 # HUD Package Definition - meson 1.8.3
-# High performance build system
+# High productivity build system
 Package: meson
 Version: 1.8.3
 Architecture: x86_64
-Section: development
+Section: build
 Depends: python3,ninja
-Description: Open source build system designed to be extremely fast and user friendly
+Description: High productivity build system
 Source: https://github.com/mesonbuild/meson/releases/download/1.8.3/meson-1.8.3.tar.gz
+[configure]
+echo "No configure step needed"
 [build]
-pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
+pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir . --break-system-packages
 [install]
-pip3 install --no-index --find-links dist --prefix=/opt/hud --root=$DESTDIR meson
-mkdir -p $DESTDIR/opt/hud/share/bash-completion/completions
-mkdir -p $DESTDIR/opt/hud/share/zsh/site-functions
+pip3 install --no-index --find-links=dist meson --root=$DESTDIR --prefix=/opt/hud --break-system-packages
 install -vDm644 data/shell-completions/bash/meson $DESTDIR/opt/hud/share/bash-completion/completions/meson
 install -vDm644 data/shell-completions/zsh/_meson $DESTDIR/opt/hud/share/zsh/site-functions/_meson
 [postinst]
 echo "✓ meson 1.8.3 installed to /opt/hud"
-/opt/hud/bin/meson --version 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/meson-1.6.1.huddef</code> (13 added, 11 removed)</summary>

```diff
--- pool/main/m/meson/meson-1.8.3.huddef
+++ sources/definitions/old/packages/meson-1.6.1.huddef
@@ -1,20 +1,22 @@
-# HUD Package Definition - meson 1.8.3
+# HUD Package Definition - meson 1.6.1
 # High performance build system
+
 Package: meson
-Version: 1.8.3
+Version: 1.6.1
 Architecture: x86_64
 Section: development
 Depends: python3,ninja
-Description: Open source build system designed to be extremely fast and user friendly
-Source: https://github.com/mesonbuild/meson/releases/download/1.8.3/meson-1.8.3.tar.gz
+Description: High performance build system
+Source: https://github.com/mesonbuild/meson/releases/download/1.6.1/meson-1.6.1.tar.gz
+
 [build]
-pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
+pip3 install --prefix=/opt/hud --root=$DESTDIR --no-deps . || \
+python3 -m pip install --prefix=/opt/hud --root=$DESTDIR --no-deps .
+
 [install]
-pip3 install --no-index --find-links dist --prefix=/opt/hud --root=$DESTDIR meson
-mkdir -p $DESTDIR/opt/hud/share/bash-completion/completions
-mkdir -p $DESTDIR/opt/hud/share/zsh/site-functions
-install -vDm644 data/shell-completions/bash/meson $DESTDIR/opt/hud/share/bash-completion/completions/meson
-install -vDm644 data/shell-completions/zsh/_meson $DESTDIR/opt/hud/share/zsh/site-functions/_meson
+# Installation done in build step
+echo "Meson installed via pip"
+
 [postinst]
-echo "✓ meson 1.8.3 installed to /opt/hud"
+echo "✓ meson 1.6.1 installed to /opt/hud"
 /opt/hud/bin/meson --version 2>/dev/null || true
```

</details>


### `nettle`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/nettle/nettle-3.10.2.huddef` | 3.10.2 | `814292a408bd` | `c531eb3a316e` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/nettle-3.10.2.huddef` | 3.10.2 | `feb2993370c9` | `6ec444dbbc8a` | alt |
| `sources/definitions/old/packages/nettle-3.10.2.huddef` | 3.10.2 | `41dc8bfc2e4a` | `6dc255c3d655` | alt |
| `sources/definitions/old/updated-packages/nettle-3.10.2.huddef` | 3.10.2 | `814292a408bd` | `c531eb3a316e` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/nettle-3.10.2.huddef</code> (9 added, 18 removed)</summary>

```diff
--- pool/main/n/nettle/nettle-3.10.2.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/nettle-3.10.2.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - nettle 3.10.2
-# Based on BLFS 12.4 documentation
+# HUD Package Definition - Nettle 3.10.2
+# Cryptographic Library
+# Low-level cryptographic library
 
 Package: nettle
@@ -6,12 +7,9 @@
 Architecture: x86_64
 Section: security
-Depends:
+Depends: gmp
 Description: Low-level cryptographic library designed to fit easily in many contexts
 Source: https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz
 
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:$PKG_CONFIG_PATH"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 $LDFLAGS"
-export CPPFLAGS="-I/opt/hud/include $CPPFLAGS"
 ./configure --prefix=/opt/hud --disable-static
 
@@ -20,17 +18,10 @@
 
 [install]
-make install DESTDIR=$DESTDIR &&
-chmod -v 755 $DESTDIR/opt/hud/lib/lib{hogweed,nettle}.so 2>/dev/null || true &&
-chmod -v 755 $DESTDIR/opt/hud/lib64/lib{hogweed,nettle}.so 2>/dev/null || true &&
-install -v -m755 -d $DESTDIR/opt/hud/share/doc/nettle-3.10.2 &&
-install -v -m644 nettle.{html,pdf} $DESTDIR/opt/hud/share/doc/nettle-3.10.2 2>/dev/null || true
+make DESTDIR=$DESTDIR install
+
+# Install documentation
+chmod -v 755 $DESTDIR/opt/hud/lib/lib*.so* 2>/dev/null || true
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "nettle 3.10.2 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ Nettle 3.10.2 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/nettle-3.10.2.huddef</code> (10 added, 14 removed)</summary>

```diff
--- pool/main/n/nettle/nettle-3.10.2.huddef
+++ sources/definitions/old/packages/nettle-3.10.2.huddef
@@ -1,18 +1,15 @@
 # HUD Package Definition - nettle 3.10.2
-# Based on BLFS 12.4 documentation
+# Auto-generated for oVirt infrastructure
 
 Package: nettle
 Version: 3.10.2
 Architecture: x86_64
-Section: security
-Depends:
-Description: Low-level cryptographic library designed to fit easily in many contexts
+Section: misc
+Depends: 
+Description: Nettle-3.10.2
 Source: https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz
 
 [configure]
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:$PKG_CONFIG_PATH"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 $LDFLAGS"
-export CPPFLAGS="-I/opt/hud/include $CPPFLAGS"
-./configure --prefix=/opt/hud --disable-static
+./configure --prefix=/opt/hud
 
 [build]
@@ -20,9 +17,8 @@
 
 [install]
-make install DESTDIR=$DESTDIR &&
-chmod -v 755 $DESTDIR/opt/hud/lib/lib{hogweed,nettle}.so 2>/dev/null || true &&
-chmod -v 755 $DESTDIR/opt/hud/lib64/lib{hogweed,nettle}.so 2>/dev/null || true &&
-install -v -m755 -d $DESTDIR/opt/hud/share/doc/nettle-3.10.2 &&
-install -v -m644 nettle.{html,pdf} $DESTDIR/opt/hud/share/doc/nettle-3.10.2 2>/dev/null || true
+make install &&
+chmod   -v   755 /usr/lib/lib{hogweed,nettle}.so &&
+install -v -m755 -d /usr/share/doc/nettle-3.10.2 &&
+install -v -m644 nettle.{html,pdf} /usr/share/doc/nettle-3.10.2
 
 [postinst]
@@ -31,5 +27,5 @@
 
 [prerm]
-# No services to stop
+# Stop service if running
 
 [postrm]
```

</details>


### `networkmanager`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/networkmanager/networkmanager-1.54.0.huddef` | 1.54.0 | `6f7f4bc0fd1f` | `529190f3dfd6` | **POOL** |
| `sources/definitions/networkmanager-1.54.0.huddef` | 1.54.0 | `2e4c3ccedb87` | `0f0ec339a2d7` | alt |
| `sources/definitions/networkmanager-huddef-packages/networkmanager-1.54.0-introspection.huddef` | 1.54.0 | `b4e4a5ddb35c` | `c77237b0ebfe` | alt |
| `sources/definitions/networkmanager-huddef-packages/networkmanager-1.54.0.huddef` | 1.54.0 | `6f7f4bc0fd1f` | `529190f3dfd6` | **= POOL** |
| `sources/definitions/old/packages/networkmanager-1.54.0.huddef` | 1.54.0 | `bf49f09410ec` | `a2bf3b4d2d28` | alt |
| `sources/definitions/old/updated-packages/networkmanager-1.54.0.huddef` | 1.54.0 | `bf49f09410ec` | `a2bf3b4d2d28` | alt |

<details><summary>diff → <code>sources/definitions/networkmanager-1.54.0.huddef</code> (1 added, 1 removed)</summary>

```diff
--- pool/main/n/networkmanager/networkmanager-1.54.0.huddef
+++ sources/definitions/networkmanager-1.54.0.huddef
@@ -7,5 +7,5 @@
 Architecture: x86_64
 Section: networking
-Depends: libndp, curl, dhcpcd, glib, iptables, libpsl, newt, polkit, vala, dbus, systemd, gnutls, gobject-introspection, libnl
+Depends: libndp, curl, dhcpcd, glib, iptables, libpsl, newt, polkit, vala, dd bus, systemd, gnutls, 10 gobject-introspection, libnl, nghttp2, brotli, libseccomp
 Recommends: wpa_supplicant
 Description: Network configuration and management daemon (with introspection/Python bindings)
```

</details>

<details><summary>diff → <code>sources/definitions/networkmanager-huddef-packages/networkmanager-1.54.0-introspection.huddef</code> (97 added, 18 removed)</summary>

```diff
--- pool/main/n/networkmanager/networkmanager-1.54.0.huddef
+++ sources/definitions/networkmanager-huddef-packages/networkmanager-1.54.0-introspection.huddef
@@ -18,28 +18,52 @@
 export CFLAGS="-I/opt/hud/include -Wno-error=array-bounds"
 export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
+
+# Critical: Set paths for GIR files
 export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share:${XDG_DATA_DIRS}"
 export GI_TYPELIB_PATH="/opt/hud/lib/girepository-1.0:/usr/lib/girepository-1.0:/usr/lib/x86_64-linux-gnu/girepository-1.0"
+
+# Verify required GIR files exist
 echo "Checking for required GIR files..."
 MISSING_GIR=0
+
 for gir in Gio-2.0.gir GLib-2.0.gir GObject-2.0.gir; do
     if [ -f "/opt/hud/share/gir-1.0/$gir" ]; then
-        echo "  Found /opt/hud/share/gir-1.0/$gir"
+        echo "  ✓ Found /opt/hud/share/gir-1.0/$gir"
     elif [ -f "/usr/share/gir-1.0/$gir" ]; then
-        echo "  Found /usr/share/gir-1.0/$gir (system)"
+        echo "  ✓ Found /usr/share/gir-1.0/$gir (system)"
+        # Copy to /opt/hud for consistency
         mkdir -p /opt/hud/share/gir-1.0
         cp -v "/usr/share/gir-1.0/$gir" /opt/hud/share/gir-1.0/
     else
-        echo "  MISSING: $gir"
+        echo "  ✗ MISSING: $gir"
         MISSING_GIR=1
     fi
 done
+
 if [ "$MISSING_GIR" = "1" ]; then
+    echo ""
     echo "ERROR: Required GIR files are missing!"
+    echo ""
+    echo "You must first rebuild GLib with introspection support:"
+    echo "  1. hud-build gobject-introspection-1.84.0.huddef"
+    echo "  2. hud-repo-manager add /var/hud-build/output/gobject-introspection-1.84.0-x86_64.hud"
+    echo "  3. hud update && hud install gobject-introspection -y"
+    echo "  4. hud-build glib-2.84.4-introspection.huddef"
+    echo "  5. hud-repo-manager add /var/hud-build/output/glib-2.84.4-x86_64.hud"
+    echo "  6. hud update && hud upgrade glib -y"
+    echo ""
+    echo "Then retry building NetworkManager."
     exit 1
 fi
+
+echo ""
 echo "All required GIR files found. Proceeding with build..."
+
+# Fix python scripts for Python 3
 grep -rl '^#!.*python$' | xargs sed -i '1s/python/&3/' 2>/dev/null || true
+
 mkdir -p build
 cd build
+
 meson setup ..                         \
       --prefix=/opt/hud                \
@@ -74,5 +98,9 @@
 cd build
 DESTDIR=$DESTDIR ninja install
+
+# Rename doc directory
 mv -v $DESTDIR/opt/hud/share/doc/NetworkManager{,-1.54.0} 2>/dev/null || true
+
+# Install man pages if docs weren't built
 if [ ! -f $DESTDIR/opt/hud/share/man/man1/nmcli.1 ]; then
     for file in $(echo ../man/*.[1578]); do
@@ -82,27 +110,78 @@
     done
 fi
+
+# Verify GIR output was created
+echo ""
 echo "Checking for generated NetworkManager GIR files..."
-ls -la $DESTDIR/opt/hud/share/gir-1.0/NM-1.0.gir 2>/dev/null || echo "WARNING: NM-1.0.gir not found"
-ls -la $DESTDIR/opt/hud/lib/girepository-1.0/NM-1.0.typelib 2>/dev/null || echo "WARNING: NM-1.0.typelib not found"
+ls -la $DESTDIR/opt/hud/share/gir-1.0/NM-1.0.gir 2>/dev/null && echo "✓ NM-1.0.gir created" || echo "WARNING: NM-1.0.gir not found"
+ls -la $DESTDIR/opt/hud/lib/girepository-1.0/NM-1.0.typelib 2>/dev/null && echo "✓ NM-1.0.typelib created" || echo "WARNING: NM-1.0.typelib not found"
 
 [postinst]
 ldconfig
+
+# Create minimal configuration
 install -vdm755 /etc/NetworkManager/conf.d
-test -f /etc/NetworkManager/NetworkManager.conf || printf '[main]\nplugins=keyfile\n' > /etc/NetworkManager/NetworkManager.conf
-printf '[main]\nauth-polkit=true\n' > /etc/NetworkManager/conf.d/polkit.conf
-printf '[main]\ndhcp=dhcpcd\n' > /etc/NetworkManager/conf.d/dhcp.conf
+
+if [ ! -f /etc/NetworkManager/NetworkManager.conf ]; then
+    cat >> /etc/NetworkManager/NetworkManager.conf << "EOF"
+[main]
+plugins=keyfile
+EOF
+fi
+
+# Enable polkit authorization
+cat > /etc/NetworkManager/conf.d/polkit.conf << "EOF"
+[main]
+auth-polkit=true
+EOF
+
+# Use dhcpcd as DHCP client
+cat > /etc/NetworkManager/conf.d/dhcp.conf << "EOF"
+[main]
+dhcp=dhcpcd
+EOF
+
+# Create netdev group for user network management
 groupadd -fg 86 netdev 2>/dev/null || true
+
+# Create polkit rule for netdev group
 install -vdm755 /usr/share/polkit-1/rules.d
-printf 'polkit.addRule(function(action, subject) { if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) { return polkit.Result.YES; } });\n' > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules
+cat > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules << "EOF"
+polkit.addRule(function(action, subject) {
+    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) {
+        return polkit.Result.YES;
+    }
+});
+EOF
+
+# Create symlinks for system access
 ln -sf /opt/hud/bin/nmcli /usr/bin/nmcli 2>/dev/null || true
 ln -sf /opt/hud/bin/nmtui /usr/bin/nmtui 2>/dev/null || true
 ln -sf /opt/hud/sbin/NetworkManager /usr/sbin/NetworkManager 2>/dev/null || true
-printf '[Unit]\nDescription=Network Manager\nDocumentation=man:NetworkManager(8)\nWants=network.target\nAfter=network-pre.target dbus.service\nBefore=network.target\n\n[Service]\nType=dbus\nBusName=org.freedesktop.NetworkManager\nExecReload=/bin/kill -HUP $MAINPID\nExecStart=/opt/hud/sbin/NetworkManager --no-daemon\nRestart=on-failure\nRestartSec=1s\nProtectSystem=true\nProtectHome=read-only\n\n[Install]\nWantedBy=multi-user.target\nAlias=dbus-org.freedesktop.NetworkManager.service\n' > /etc/systemd/system/NetworkManager.service
-printf '[Unit]\nDescription=Network Manager Wait Online\nRequires=NetworkManager.service\nAfter=NetworkManager.service\nBefore=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/opt/hud/bin/nm-online -s -q\nRemainAfterExit=yes\n\n[Install]\nWantedBy=network-online.target\n' > /etc/systemd/system/NetworkManager-wait-online.service
-printf '[Unit]\nDescription=Network Manager Script Dispatcher Service\nWants=NetworkManager.service\nAfter=NetworkManager.service\n\n[Service]\nType=dbus\nBusName=org.freedesktop.nm_dispatcher\nExecStart=/opt/hud/libexec/nm-dispatcher\nNotifyAccess=main\n\n[Install]\nWantedBy=NetworkManager.service\n' > /etc/systemd/system/NetworkManager-dispatcher.service
-systemctl daemon-reload
-systemctl enable NetworkManager.service
-systemctl start NetworkManager.service || true
-echo "NetworkManager 1.54.0 installed and enabled"
-echo "Commands: nmtui, nmcli"
-echo "Check status: systemctl status NetworkManager"
+
+# Install systemd service (copy to system location)
+if [ -f /opt/hud/lib/systemd/system/NetworkManager.service ]; then
+    cp -f /opt/hud/lib/systemd/system/NetworkManager*.service /usr/lib/systemd/system/
+fi
+
+systemctl daemon-reload 2>/dev/null || true
+
+echo ""
+echo "✓ NetworkManager 1.54.0 installed to /opt/hud (WITH INTROSPECTION)"
+echo ""
+echo "Introspection files:"
+ls -la /opt/hud/share/gir-1.0/NM-1.0.gir 2>/dev/null || echo "  NM-1.0.gir: not found"
+ls -la /opt/hud/lib/girepository-1.0/NM-1.0.typelib 2>/dev/null || echo "  NM-1.0.typelib: not found"
+echo ""
+echo "Python usage example:"
+echo "  import gi"
+echo "  gi.require_version('NM', '1.0')"
+echo "  from gi.repository import NM"
+echo ""
+echo "To enable NetworkManager:"
+echo "  1. Disable systemd-networkd if in use: systemctl disable systemd-networkd"
+echo "  2. Enable NetworkManager: systemctl enable NetworkManager"
+echo "  3. Start NetworkManager: systemctl start NetworkManager"
+echo ""
+echo "To allow users to manage networks, add them to the netdev group:"
+echo "  usermod -a -G netdev <username>"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/networkmanager-1.54.0.huddef</code> (56 added, 94 removed)</summary>

```diff
--- pool/main/n/networkmanager/networkmanager-1.54.0.huddef
+++ sources/definitions/old/packages/networkmanager-1.54.0.huddef
@@ -1,108 +1,70 @@
 # HUD Package Definition - NetworkManager 1.54.0
-# Network connection manager daemon - WITH INTROSPECTION
-# Requires: GLib rebuilt with introspection (provides Gio-2.0.gir, GLib-2.0.gir, GObject-2.0.gir)
+# Network connection manager and user applications
 
 Package: networkmanager
 Version: 1.54.0
 Architecture: x86_64
-Section: networking
-Depends: libndp, curl, dhcpcd, glib, iptables, libpsl, newt, polkit, vala, dbus, systemd, gnutls, gobject-introspection, libnl
-Recommends: wpa_supplicant
-Description: Network configuration and management daemon (with introspection/Python bindings)
+Section: network
+Depends: glib2,libndp,curl,nss,dbus,libpsl,polkit,elogind,jansson,libgudev,newt,iptables
+Description: Network connection manager and user applications
 Source: https://gitlab.freedesktop.org/NetworkManager/NetworkManager/-/releases/1.54.0/downloads/NetworkManager-1.54.0.tar.xz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include -Wno-error=array-bounds"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share:${XDG_DATA_DIRS}"
-export GI_TYPELIB_PATH="/opt/hud/lib/girepository-1.0:/usr/lib/girepository-1.0:/usr/lib/x86_64-linux-gnu/girepository-1.0"
-echo "Checking for required GIR files..."
-MISSING_GIR=0
-for gir in Gio-2.0.gir GLib-2.0.gir GObject-2.0.gir; do
-    if [ -f "/opt/hud/share/gir-1.0/$gir" ]; then
-        echo "  Found /opt/hud/share/gir-1.0/$gir"
-    elif [ -f "/usr/share/gir-1.0/$gir" ]; then
-        echo "  Found /usr/share/gir-1.0/$gir (system)"
-        mkdir -p /opt/hud/share/gir-1.0
-        cp -v "/usr/share/gir-1.0/$gir" /opt/hud/share/gir-1.0/
-    else
-        echo "  MISSING: $gir"
-        MISSING_GIR=1
-    fi
-done
-if [ "$MISSING_GIR" = "1" ]; then
-    echo "ERROR: Required GIR files are missing!"
-    exit 1
-fi
-echo "All required GIR files found. Proceeding with build..."
-grep -rl '^#!.*python$' | xargs sed -i '1s/python/&3/' 2>/dev/null || true
-mkdir -p build
-cd build
-meson setup ..                         \
-      --prefix=/opt/hud                \
-      --sysconfdir=/etc                \
-      --localstatedir=/var             \
-      --buildtype=release              \
-      -D werror=false                  \
-      -D crypto=gnutls                 \
-      -D libaudit=no                   \
-      -D nmtui=true                    \
-      -D ovs=false                     \
-      -D ppp=false                     \
-      -D nbft=false                    \
-      -D selinux=false                 \
-      -D qt=false                      \
-      -D session_tracking=systemd      \
-      -D nm_cloud_setup=false          \
-      -D modem_manager=false           \
-      -D introspection=true            \
-      -D vapi=true                     \
-      -D tests=no
+mkdir -p build && cd build && meson setup .. \
+    --prefix=/opt/hud \
+    --sysconfdir=/opt/hud/etc \
+    --localstatedir=/opt/hud/var \
+    -Dlibaudit=no \
+    -Dlibpsl=true \
+    -Dnmtui=true \
+    -Dovs=false \
+    -Dppp=false \
+    -Dselinux=false \
+    -Dsession_tracking_consolekit=false \
+    -Dsession_tracking=elogind \
+    -Dmodem_manager=false \
+    -Dsystemdsystemunitdir=/opt/hud/lib/systemd/system \
+    -Dsystemd_journal=false \
+    -Dqt=false \
+    -Ddocs=false \
+    -Dtests=no \
+    -Dcrypto=nss \
+    -Dconfig_plugins_default=keyfile
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export XDG_DATA_DIRS="/opt/hud/share:/usr/local/share:/usr/share:${XDG_DATA_DIRS}"
-export GI_TYPELIB_PATH="/opt/hud/lib/girepository-1.0:/usr/lib/girepository-1.0"
-cd build
-ninja
+cd build && ninja -j$(nproc)
 
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
-mv -v $DESTDIR/opt/hud/share/doc/NetworkManager{,-1.54.0} 2>/dev/null || true
-if [ ! -f $DESTDIR/opt/hud/share/man/man1/nmcli.1 ]; then
-    for file in $(echo ../man/*.[1578]); do
-        section=${file##*.}
-        install -vdm755 $DESTDIR/opt/hud/share/man/man$section
-        install -vm644 $file $DESTDIR/opt/hud/share/man/man$section/
-    done
-fi
-echo "Checking for generated NetworkManager GIR files..."
-ls -la $DESTDIR/opt/hud/share/gir-1.0/NM-1.0.gir 2>/dev/null || echo "WARNING: NM-1.0.gir not found"
-ls -la $DESTDIR/opt/hud/lib/girepository-1.0/NM-1.0.typelib 2>/dev/null || echo "WARNING: NM-1.0.typelib not found"
+cd build && DESTDIR=$DESTDIR ninja install
 
 [postinst]
-ldconfig
-install -vdm755 /etc/NetworkManager/conf.d
-test -f /etc/NetworkManager/NetworkManager.conf || printf '[main]\nplugins=keyfile\n' > /etc/NetworkManager/NetworkManager.conf
-printf '[main]\nauth-polkit=true\n' > /etc/NetworkManager/conf.d/polkit.conf
-printf '[main]\ndhcp=dhcpcd\n' > /etc/NetworkManager/conf.d/dhcp.conf
-groupadd -fg 86 netdev 2>/dev/null || true
-install -vdm755 /usr/share/polkit-1/rules.d
-printf 'polkit.addRule(function(action, subject) { if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("netdev")) { return polkit.Result.YES; } });\n' > /usr/share/polkit-1/rules.d/org.freedesktop.NetworkManager.rules
-ln -sf /opt/hud/bin/nmcli /usr/bin/nmcli 2>/dev/null || true
-ln -sf /opt/hud/bin/nmtui /usr/bin/nmtui 2>/dev/null || true
-ln -sf /opt/hud/sbin/NetworkManager /usr/sbin/NetworkManager 2>/dev/null || true
-printf '[Unit]\nDescription=Network Manager\nDocumentation=man:NetworkManager(8)\nWants=network.target\nAfter=network-pre.target dbus.service\nBefore=network.target\n\n[Service]\nType=dbus\nBusName=org.freedesktop.NetworkManager\nExecReload=/bin/kill -HUP $MAINPID\nExecStart=/opt/hud/sbin/NetworkManager --no-daemon\nRestart=on-failure\nRestartSec=1s\nProtectSystem=true\nProtectHome=read-only\n\n[Install]\nWantedBy=multi-user.target\nAlias=dbus-org.freedesktop.NetworkManager.service\n' > /etc/systemd/system/NetworkManager.service
-printf '[Unit]\nDescription=Network Manager Wait Online\nRequires=NetworkManager.service\nAfter=NetworkManager.service\nBefore=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/opt/hud/bin/nm-online -s -q\nRemainAfterExit=yes\n\n[Install]\nWantedBy=network-online.target\n' > /etc/systemd/system/NetworkManager-wait-online.service
-printf '[Unit]\nDescription=Network Manager Script Dispatcher Service\nWants=NetworkManager.service\nAfter=NetworkManager.service\n\n[Service]\nType=dbus\nBusName=org.freedesktop.nm_dispatcher\nExecStart=/opt/hud/libexec/nm-dispatcher\nNotifyAccess=main\n\n[Install]\nWantedBy=NetworkManager.service\n' > /etc/systemd/system/NetworkManager-dispatcher.service
-systemctl daemon-reload
-systemctl enable NetworkManager.service
-systemctl start NetworkManager.service || true
-echo "NetworkManager 1.54.0 installed and enabled"
-echo "Commands: nmtui, nmcli"
-echo "Check status: systemctl status NetworkManager"
+ldconfig 2>/dev/null || true
+# Create necessary directories
+mkdir -p /opt/hud/etc/NetworkManager/conf.d 2>/dev/null || true
+mkdir -p /opt/hud/etc/NetworkManager/system-connections 2>/dev/null || true
+mkdir -p /opt/hud/var/lib/NetworkManager 2>/dev/null || true
+mkdir -p /opt/hud/var/run/NetworkManager 2>/dev/null || true
+chmod 700 /opt/hud/etc/NetworkManager/system-connections 2>/dev/null || true
+# Create basic config if not exists
+if [ ! -f /opt/hud/etc/NetworkManager/NetworkManager.conf ]; then
+    cat > /opt/hud/etc/NetworkManager/NetworkManager.conf << 'NMCONF'
+[main]
+plugins=keyfile
+[keyfile]
+unmanaged-devices=none
+NMCONF
+fi
+echo "✓ NetworkManager 1.54.0 installed to /opt/hud"
+echo "  To start: systemctl start hud-networkmanager"
+echo "  CLI tool: /opt/hud/bin/nmcli"
+echo "  TUI tool: /opt/hud/bin/nmtui"
+
+[prerm]
+systemctl stop hud-networkmanager 2>/dev/null || true
+systemctl disable hud-networkmanager 2>/dev/null || true
+
+[postrm]
+ldconfig 2>/dev/null || true
+
+[service]
+networkmanager
```

</details>


### `newt`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/newt/newt-0.52.25.huddef` | 0.52.25 | `195cd16c0132` | `236d07488e88` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/newt-0.52.25.huddef` | 0.52.25 | `195cd16c0132` | `236d07488e88` | **= POOL** |
| `sources/definitions/old/packages/newt-0.52.25.huddef` | 0.52.25 | `182c1cc9410f` | `f65e252accc0` | alt |
| `sources/definitions/old/updated-packages/newt-0.52.25.huddef` | 0.52.25 | `182c1cc9410f` | `f65e252accc0` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/newt-0.52.25.huddef</code> (12 added, 27 removed)</summary>

```diff
--- pool/main/n/newt/newt-0.52.25.huddef
+++ sources/definitions/old/packages/newt-0.52.25.huddef
@@ -1,5 +1,4 @@
-# HUD Package Definition - Newt 0.52.25
-# Text-mode widget library for user interfaces
-# Required by NetworkManager for nmtui
+# HUD Package Definition - newt 0.52.25
+# Text mode interface library
 
 Package: newt
@@ -7,31 +6,17 @@
 Architecture: x86_64
 Section: libraries
-Depends: popt, slang, gpm, python
-Description: Text-mode widget-based user interface library
+Depends: slang,popt
+Description: Text mode interface library (for nmtui)
 Source: https://releases.pagure.org/newt/newt-0.52.25.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-# Disable static library installation
-sed -e '/install -m 644 $(LIBNEWT)/ s/^/#/' \
-    -e '/$(LIBNEWT):/,/rv/ s/^/#/'          \
-    -e 's/$(LIBNEWT)/$(LIBNEWTSH)/g'        \
-    -i Makefile.in
-
-# Detect Python version
-PYTHON_VER=$(python3 --version 2>&1 | sed 's/Python //' | cut -d. -f1,2)
-
-./configure --prefix=/opt/hud \
-            --with-gpm-support \
-            --with-python=python${PYTHON_VER}
+./configure \
+    --prefix=/opt/hud \
+    --with-gpm-support \
+    --without-tcl \
+    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
+    CPPFLAGS="-I/opt/hud/include"
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make -j$(nproc)
 
@@ -40,4 +25,4 @@
 
 [postinst]
-ldconfig
-echo "✓ Newt 0.52.25 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "✓ newt 0.52.25 installed to /opt/hud"
```

</details>


### `nftables`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/nftables/nftables-1.1.1.huddef` | 1.1.1 | `1a7d7a72a6ff` | `f421354ade0b` | **POOL** |
| `sources/definitions/13 Feb 2026/nftables-1.1.1.huddef` | 1.1.1 | `8d4774bb0bf0` | `f5f8eb89d52c` | alt |
| `sources/definitions/libvirt/nftables-1.1.1.huddef` | 1.1.1 | `23255a31f464` | `cff8f1a4d925` | alt |
| `sources/definitions/libvirt_9feb_2026/nftables-1.1.1.huddef` | 1.1.1 | `1a7d7a72a6ff` | `f421354ade0b` | **= POOL** |

<details><summary>diff → <code>sources/definitions/13 Feb 2026/nftables-1.1.1.huddef</code> (19 added, 3 removed)</summary>

```diff
--- pool/main/n/nftables/nftables-1.1.1.huddef
+++ sources/definitions/13 Feb 2026/nftables-1.1.1.huddef
@@ -47,8 +47,13 @@
 DESTDIR=$DESTDIR make install
 
+# Ensure Python nftables module is complete
+# Copy the Python source files that make may have missed
+NFTPY_DEST="$DESTDIR/opt/hud/lib/python3.13/site-packages/nftables"
+mkdir -p "$NFTPY_DEST"
+cp -f py/src/nftables.py "$NFTPY_DEST/" 2>/dev/null || true
+cp -f py/src/__init__.py "$NFTPY_DEST/" 2>/dev/null || true
+
 [postinst]
-ldconfig
-
-# Add library path to system ldconfig
+# Add library paths to ldconfig
 echo "/opt/hud/lib" > /etc/ld.so.conf.d/hud.conf
 echo "/opt/hud/lib64" >> /etc/ld.so.conf.d/hud.conf
@@ -58,4 +63,15 @@
 ln -sf /opt/hud/sbin/nft /usr/sbin/nft 2>/dev/null || true
 ln -sf /opt/hud/sbin/nft /sbin/nft 2>/dev/null || true
+
+# Ensure Python nftables module has the nftables.py file
+# (The module needs both __init__.py and nftables.py)
+NFTPY_DIR="/opt/hud/lib/python3.13/site-packages/nftables"
+if [ -d "$NFTPY_DIR" ] && [ ! -f "$NFTPY_DIR/nftables.py" ]; then
+    # Copy from build staging if available
+    BUILD_PY=$(find /var/hud-build/staging/nftables-*/src/nftables-*/py/src -name "nftables.py" 2>/dev/null | head -1)
+    BUILD_INIT=$(find /var/hud-build/staging/nftables-*/src/nftables-*/py/src -name "__init__.py" 2>/dev/null | head -1)
+    [ -n "$BUILD_PY" ] && cp "$BUILD_PY" "$NFTPY_DIR/"
+    [ -n "$BUILD_INIT" ] && [ ! -f "$NFTPY_DIR/__init__.py" ] && cp "$BUILD_INIT" "$NFTPY_DIR/"
+fi
 
 # Create basic nftables config
```

</details>

<details><summary>diff → <code>sources/definitions/libvirt/nftables-1.1.1.huddef</code> (21 added, 63 removed)</summary>

```diff
--- pool/main/n/nftables/nftables-1.1.1.huddef
+++ sources/definitions/libvirt/nftables-1.1.1.huddef
@@ -1,20 +1,5 @@
 # HUD Package Definition - nftables 1.1.1
-# Netfilter tables - modern Linux firewall subsystem
-# Required by firewalld and libvirt for packet filtering
-# Reference: https://netfilter.org/projects/nftables/
-#
-# KERNEL REQUIREMENTS:
-# The following kernel options must be enabled:
-#   CONFIG_NF_TABLES=y
-#   CONFIG_NF_TABLES_INET=y (CRITICAL - inet family support)
-#   CONFIG_NF_TABLES_NETDEV=y
-#   CONFIG_NFT_CT=m
-#   CONFIG_NFT_LOG=m
-#   CONFIG_NFT_LIMIT=m
-#   CONFIG_NFT_MASQ=m
-#   CONFIG_NFT_NAT=m
-#   CONFIG_NFT_REJECT=m
-#   CONFIG_NFT_COMPAT=m
-#   CONFIG_NFT_COUNTER=y (built-in recommended)
+# Netfilter tables userspace tools with Python bindings
+# Required by firewalld
 
 Package: nftables
@@ -22,67 +7,40 @@
 Architecture: x86_64
 Section: network
-Depends: libnftnl, libmnl, readline, gmp, jansson
-Description: Netfilter tables userspace tools (modern iptables replacement)
-Source: https://www.netfilter.org/projects/nftables/files/nftables-1.1.1.tar.xz
+Depends: libmnl, libnftnl, libedit, gmp, python3, jansson
+Description: Netfilter tables userspace tools and Python bindings
+Source: https://netfilter.org/projects/nftables/files/nftables-1.1.1.tar.xz
 
 [configure]
 export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 export CFLAGS="-I/opt/hud/include"
 export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-./configure --prefix=/opt/hud          \
-            --sysconfdir=/etc          \
-            --localstatedir=/var       \
-            --with-json                \
+export PYTHON=/usr/bin/python3
+./configure --prefix=/opt/hud           \
+            --sysconfdir=/etc           \
             --with-python-bin=/usr/bin/python3 \
-            --enable-python
+            --enable-python             \
+            --with-json                 \
+            --disable-man-doc
 
 [build]
 export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
 export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-make -j$(nproc)
+make
 
 [install]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
 DESTDIR=$DESTDIR make install
+cd py
+/usr/bin/python3 setup.py build
+/usr/bin/python3 setup.py install --prefix=/opt/hud --root=$DESTDIR
 
 [postinst]
 ldconfig
-
-# Add library path to system ldconfig
-echo "/opt/hud/lib" > /etc/ld.so.conf.d/hud.conf
-echo "/opt/hud/lib64" >> /etc/ld.so.conf.d/hud.conf
-ldconfig
-
-# Create symlinks
 ln -sf /opt/hud/sbin/nft /usr/sbin/nft 2>/dev/null || true
-ln -sf /opt/hud/sbin/nft /sbin/nft 2>/dev/null || true
-
-# Create basic nftables config
-install -vdm755 /etc/nftables
-cat > /etc/nftables/nftables.conf << 'EOF'
-#!/usr/sbin/nft -f
-# Basic nftables configuration
-# Managed by firewalld when firewalld is running
-
-flush ruleset
-
-table inet filter {
-    chain input {
-        type filter hook input priority 0; policy accept;
-    }
-    chain forward {
-        type filter hook forward priority 0; policy accept;
-    }
-    chain output {
-        type filter hook output priority 0; policy accept;
-    }
-}
-EOF
-
-echo ""
 echo "nftables 1.1.1 installed"
-echo "Binary: /opt/hud/sbin/nft (symlinked to /usr/sbin/nft)"
-echo ""
-echo "Test: nft list tables"
-echo "Note: firewalld manages nftables rules when running"
+echo "Commands: nft"
+echo "Test Python: PYTHONPATH=/opt/hud/lib/python3.13/site-packages python3 -c \"from nftables import Nftables; print('OK')\""
```

</details>


### `ninja`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/ninja/ninja-1.13.1.huddef` | 1.13.1 | `75d51587acbc` | `eec2d26dc65b` | **POOL** |
| `sources/definitions/old/0/ninja-1.13.1.huddef` | 1.13.1 | `874910c26575` | `b0c659b1819f` | alt |
| `sources/definitions/old/packages/ninja-1.12.1.huddef` | 1.12.1 | `8c23d292da40` | `3453879161af` | alt |
| `sources/definitions/old/updated-packages/ninja-1.13.1.huddef` | 1.13.1 | `75d51587acbc` | `eec2d26dc65b` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/ninja-1.13.1.huddef</code> (7 added, 18 removed)</summary>

```diff
--- pool/main/n/ninja/ninja-1.13.1.huddef
+++ sources/definitions/old/0/ninja-1.13.1.huddef
@@ -1,31 +1,20 @@
 # HUD Package Definition - ninja 1.13.1
-# Small build system with focus on speed
+# Small build system with a focus on speed
 Package: ninja
 Version: 1.13.1
 Architecture: x86_64
-Section: development
+Section: build
 Depends: python3
 Description: Small build system with a focus on speed
-Source: https://github.com/ninja-build/ninja/archive/refs/tags/v1.13.1.tar.gz
+Source: https://github.com/ninja-build/ninja/archive/v1.13.1/ninja-1.13.1.tar.gz
 [configure]
-# Optional: Apply NINJAJOBS environment variable support
-sed -i '/int Guess/a \
-  int   j = 0;\
-  char* jobs = getenv( "NINJAJOBS" );\
-  if ( jobs != NULL ) j = atoi( jobs );\
-  if ( j > 0 ) return j;\
-' src/ninja.cc
-python3 configure.py --bootstrap --verbose
+sed -i '/int Guess/a int j = 0;' src/ninja.cc
+python3 configure.py --bootstrap
 [build]
-# Bootstrap already builds ninja
-echo "Ninja built during configure"
+echo "Build completed during configure"
 [install]
-mkdir -p $DESTDIR/opt/hud/bin
-mkdir -p $DESTDIR/opt/hud/share/bash-completion/completions
-mkdir -p $DESTDIR/opt/hud/share/zsh/site-functions
-install -vm755 ninja $DESTDIR/opt/hud/bin/ninja
+install -vDm755 ninja $DESTDIR/opt/hud/bin/ninja
 install -vDm644 misc/bash-completion $DESTDIR/opt/hud/share/bash-completion/completions/ninja
 install -vDm644 misc/zsh-completion $DESTDIR/opt/hud/share/zsh/site-functions/_ninja
 [postinst]
 echo "✓ ninja 1.13.1 installed to /opt/hud"
-/opt/hud/bin/ninja --version 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/ninja-1.12.1.huddef</code> (13 added, 15 removed)</summary>

```diff
--- pool/main/n/ninja/ninja-1.13.1.huddef
+++ sources/definitions/old/packages/ninja-1.12.1.huddef
@@ -1,31 +1,29 @@
-# HUD Package Definition - ninja 1.13.1
+# HUD Package Definition - ninja 1.12.1
 # Small build system with focus on speed
+
 Package: ninja
-Version: 1.13.1
+Version: 1.12.1
 Architecture: x86_64
 Section: development
 Depends: python3
 Description: Small build system with a focus on speed
-Source: https://github.com/ninja-build/ninja/archive/refs/tags/v1.13.1.tar.gz
+Source: https://github.com/ninja-build/ninja/archive/refs/tags/v1.12.1.tar.gz
+
 [configure]
-# Optional: Apply NINJAJOBS environment variable support
-sed -i '/int Guess/a \
-  int   j = 0;\
-  char* jobs = getenv( "NINJAJOBS" );\
-  if ( jobs != NULL ) j = atoi( jobs );\
-  if ( j > 0 ) return j;\
-' src/ninja.cc
-python3 configure.py --bootstrap --verbose
+python3 configure.py --bootstrap
+
 [build]
 # Bootstrap already builds ninja
 echo "Ninja built during configure"
+
 [install]
 mkdir -p $DESTDIR/opt/hud/bin
 mkdir -p $DESTDIR/opt/hud/share/bash-completion/completions
 mkdir -p $DESTDIR/opt/hud/share/zsh/site-functions
-install -vm755 ninja $DESTDIR/opt/hud/bin/ninja
-install -vDm644 misc/bash-completion $DESTDIR/opt/hud/share/bash-completion/completions/ninja
-install -vDm644 misc/zsh-completion $DESTDIR/opt/hud/share/zsh/site-functions/_ninja
+install -m 755 ninja $DESTDIR/opt/hud/bin/ninja
+install -m 644 misc/bash-completion $DESTDIR/opt/hud/share/bash-completion/completions/ninja 2>/dev/null || true
+install -m 644 misc/zsh-completion $DESTDIR/opt/hud/share/zsh/site-functions/_ninja 2>/dev/null || true
+
 [postinst]
-echo "✓ ninja 1.13.1 installed to /opt/hud"
+echo "✓ ninja 1.12.1 installed to /opt/hud"
 /opt/hud/bin/ninja --version 2>/dev/null || true
```

</details>


### `nspr`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/nspr/nspr-4.37.huddef` | 4.37 | `4fada8196e10` | `12d629606a04` | **POOL** |
| `sources/definitions/old/packages/nspr-4.36.huddef` | 4.36 | `7c84f51e8b28` | `21c9370f2509` | alt |
| `sources/definitions/old/packages/nspr-4.37.huddef` | 4.37 | `0eb44b3435e4` | `d97971ae8101` | alt |
| `sources/definitions/old/updated-packages/nspr-4.37.huddef` | 4.37 | `4fada8196e10` | `12d629606a04` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/nspr-4.36.huddef</code> (14 added, 25 removed)</summary>

```diff
--- pool/main/n/nspr/nspr-4.37.huddef
+++ sources/definitions/old/packages/nspr-4.36.huddef
@@ -1,38 +1,27 @@
-# HUD Package Definition - nspr 4.37
-# Based on BLFS 12.4 documentation
-# Note: Required dependency for NSS
+# HUD Package Definition - nspr 4.36
+# Netscape Portable Runtime
 
 Package: nspr
-Version: 4.37
+Version: 4.36
 Architecture: x86_64
-Section: security
+Section: libraries
 Depends:
-Description: Netscape Portable Runtime - platform abstraction library for NSS
-Source: https://archive.mozilla.org/pub/nspr/releases/v4.37/src/nspr-4.37.tar.gz
+Description: Netscape Portable Runtime
+Source: https://archive.mozilla.org/pub/nspr/releases/v4.36/src/nspr-4.36.tar.gz
 
 [configure]
-cd nspr &&
-sed -ri '/^RELEASE/s/^/#/' pr/src/misc/Makefile.in &&
-sed -i 's#$(LIBRARY) ##'   config/rules.mk         &&
-./configure --prefix=/opt/hud \
-            --with-mozilla \
-            --with-pthreads \
-            $([ $(uname -m) = x86_64 ] && echo --enable-64bit)
+cd nspr && ./configure \
+    --prefix=/opt/hud \
+    --with-mozilla \
+    --with-pthreads \
+    --enable-64bit
 
 [build]
-cd nspr &&
-make -j$(nproc)
+cd nspr && make -j$(nproc)
 
 [install]
-cd nspr &&
-make install DESTDIR=$DESTDIR
+cd nspr && make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "nspr 4.37 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ nspr 4.36 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/nspr-4.37.huddef</code> (8 added, 17 removed)</summary>

```diff
--- pool/main/n/nspr/nspr-4.37.huddef
+++ sources/definitions/old/packages/nspr-4.37.huddef
@@ -1,30 +1,21 @@
 # HUD Package Definition - nspr 4.37
-# Based on BLFS 12.4 documentation
-# Note: Required dependency for NSS
+# Auto-generated for oVirt infrastructure
 
 Package: nspr
 Version: 4.37
 Architecture: x86_64
-Section: security
-Depends:
-Description: Netscape Portable Runtime - platform abstraction library for NSS
+Section: libraries
+Depends: 
+Description: NSPR-4.37
 Source: https://archive.mozilla.org/pub/nspr/releases/v4.37/src/nspr-4.37.tar.gz
 
 [configure]
-cd nspr &&
-sed -ri '/^RELEASE/s/^/#/' pr/src/misc/Makefile.in &&
-sed -i 's#$(LIBRARY) ##'   config/rules.mk         &&
-./configure --prefix=/opt/hud \
-            --with-mozilla \
-            --with-pthreads \
-            $([ $(uname -m) = x86_64 ] && echo --enable-64bit)
+cd nspr && ./configure --prefix=/opt/hud --enable-64bit
 
 [build]
-cd nspr &&
-make -j$(nproc)
+cd nspr && make
 
 [install]
-cd nspr &&
-make install DESTDIR=$DESTDIR
+cd nspr && make DESTDIR=$DESTDIR install
 
 [postinst]
@@ -33,5 +24,5 @@
 
 [prerm]
-# No services to stop
+# Stop service if running
 
 [postrm]
```

</details>


### `nss`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/packages/nss-3.108.huddef` | 3.108 | `543305679f91` | `c409e4211d58` | alt |
| `sources/definitions/old/packages/nss-3.115.huddef` | 3.115 | `c7c85cbf33fa` | `5eda3d3246dc` | alt |
| `sources/definitions/old/updated-packages/nss-3.115.huddef` | 3.115 | `d7d11244f261` | `da21c288b6a2` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/packages/nss-3.108.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/nss-3.115.huddef</code> (18 added, 45 removed)</summary>

```diff
--- sources/definitions/old/packages/nss-3.108.huddef
+++ sources/definitions/old/packages/nss-3.115.huddef
@@ -1,56 +1,29 @@
-# HUD Package Definition - nss 3.108
-# Network Security Services
+# HUD Package Definition - nss 3.115
+# Auto-generated for oVirt infrastructure
 
 Package: nss
-Version: 3.108
+Version: 3.115
 Architecture: x86_64
 Section: security
-Depends: nspr,sqlite,zlib,perl
-Description: Network Security Services libraries
-Source: https://archive.mozilla.org/pub/security/nss/releases/NSS_3_108_RTM/src/nss-3.108.tar.gz
+Depends: nspr,make-ca,p11-kit,sqlite
+Description: NSS-3.115
+Source: https://archive.mozilla.org/pub/security/nss/releases/NSS_3_115_RTM/src/nss-3.115.tar.gz
+
+[configure]
+./configure --prefix=/opt/hud
 
 [build]
-cd nss && make -j$(nproc) \
-    BUILD_OPT=1 \
-    NSPR_INCLUDE_DIR=/opt/hud/include/nspr \
-    NSPR_LIB_DIR=/opt/hud/lib \
-    USE_SYSTEM_ZLIB=1 \
-    ZLIB_LIBS=-lz \
-    NSS_USE_SYSTEM_SQLITE=1 \
-    USE_64=1 \
-    NSS_ENABLE_WERROR=0
+cd nss && make BUILD_OPT=1 USE_64=1 NSS_USE_SYSTEM_SQLITE=1 NSS_ENABLE_WERROR=0
 
 [install]
-cd dist
-mkdir -p $DESTDIR/opt/hud/lib/pkgconfig
-mkdir -p $DESTDIR/opt/hud/include/nss
-mkdir -p $DESTDIR/opt/hud/bin
-# Install libraries
-install -m 755 Linux*/lib/*.so $DESTDIR/opt/hud/lib/
-install -m 644 Linux*/lib/*.chk $DESTDIR/opt/hud/lib/ 2>/dev/null || true
-install -m 644 Linux*/lib/libcrmf.a $DESTDIR/opt/hud/lib/ 2>/dev/null || true
-# Install headers
-cp -RL public/nss/* $DESTDIR/opt/hud/include/nss/
-cp -RL private/nss/* $DESTDIR/opt/hud/include/nss/ 2>/dev/null || true
-# Install tools
-for tool in certutil cmsutil crlutil modutil pk12util signtool signver ssltap; do
-    install -m 755 Linux*/bin/$tool $DESTDIR/opt/hud/bin/ 2>/dev/null || true
-done
-# Create pkg-config file
-cat > $DESTDIR/opt/hud/lib/pkgconfig/nss.pc << 'NSSPC'
-prefix=/opt/hud
-exec_prefix=${prefix}
-libdir=${exec_prefix}/lib
-includedir=${prefix}/include/nss
-
-Name: NSS
-Description: Network Security Services
-Version: 3.108
-Requires: nspr >= 4.35
-Libs: -L${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
-Cflags: -I${includedir}
-NSSPC
+cd dist && mkdir -p $DESTDIR/opt/hud/lib $DESTDIR/opt/hud/include/nss && cp Linux*/lib/*.so $DESTDIR/opt/hud/lib/ && cp -r public/nss/* $DESTDIR/opt/hud/include/nss/
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ nss 3.108 installed to /opt/hud"
+echo "nss 3.115 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/updated-packages/nss-3.115.huddef</code> (39 added, 45 removed)</summary>

```diff
--- sources/definitions/old/packages/nss-3.108.huddef
+++ sources/definitions/old/updated-packages/nss-3.115.huddef
@@ -1,56 +1,50 @@
-# HUD Package Definition - nss 3.108
-# Network Security Services
+# HUD Package Definition - nss 3.115
+# Based on BLFS 12.4 documentation
 
 Package: nss
-Version: 3.108
+Version: 3.115
 Architecture: x86_64
 Section: security
-Depends: nspr,sqlite,zlib,perl
-Description: Network Security Services libraries
-Source: https://archive.mozilla.org/pub/security/nss/releases/NSS_3_108_RTM/src/nss-3.108.tar.gz
+Depends: nspr,sqlite
+Description: Network Security Services - libraries for cross-platform security-enabled client/server applications
+Source: https://archive.mozilla.org/pub/security/nss/releases/NSS_3_115_RTM/src/nss-3.115.tar.gz
+
+[configure]
+# NSS does not use autotools - apply standalone patch if available
+# patch -Np1 -i ../nss-standalone-1.patch 2>/dev/null || true
 
 [build]
-cd nss && make -j$(nproc) \
-    BUILD_OPT=1 \
-    NSPR_INCLUDE_DIR=/opt/hud/include/nspr \
-    NSPR_LIB_DIR=/opt/hud/lib \
-    USE_SYSTEM_ZLIB=1 \
-    ZLIB_LIBS=-lz \
-    NSS_USE_SYSTEM_SQLITE=1 \
-    USE_64=1 \
-    NSS_ENABLE_WERROR=0
+cd nss &&
+make BUILD_OPT=1                      \
+  NSPR_INCLUDE_DIR=/usr/include/nspr  \
+  USE_SYSTEM_ZLIB=1                   \
+  ZLIB_LIBS=-lz                       \
+  NSS_ENABLE_WERROR=0                 \
+  $([ $(uname -m) = x86_64 ] && echo USE_64=1) \
+  $([ -f /usr/include/sqlite3.h ] && echo NSS_USE_SYSTEM_SQLITE=1)
 
 [install]
-cd dist
-mkdir -p $DESTDIR/opt/hud/lib/pkgconfig
-mkdir -p $DESTDIR/opt/hud/include/nss
-mkdir -p $DESTDIR/opt/hud/bin
-# Install libraries
-install -m 755 Linux*/lib/*.so $DESTDIR/opt/hud/lib/
-install -m 644 Linux*/lib/*.chk $DESTDIR/opt/hud/lib/ 2>/dev/null || true
-install -m 644 Linux*/lib/libcrmf.a $DESTDIR/opt/hud/lib/ 2>/dev/null || true
-# Install headers
-cp -RL public/nss/* $DESTDIR/opt/hud/include/nss/
-cp -RL private/nss/* $DESTDIR/opt/hud/include/nss/ 2>/dev/null || true
-# Install tools
-for tool in certutil cmsutil crlutil modutil pk12util signtool signver ssltap; do
-    install -m 755 Linux*/bin/$tool $DESTDIR/opt/hud/bin/ 2>/dev/null || true
-done
-# Create pkg-config file
-cat > $DESTDIR/opt/hud/lib/pkgconfig/nss.pc << 'NSSPC'
-prefix=/opt/hud
-exec_prefix=${prefix}
-libdir=${exec_prefix}/lib
-includedir=${prefix}/include/nss
-
-Name: NSS
-Description: Network Security Services
-Version: 3.108
-Requires: nspr >= 4.35
-Libs: -L${libdir} -lnss3 -lnssutil3 -lsmime3 -lssl3
-Cflags: -I${includedir}
-NSSPC
+cd dist &&
+install -v -m755 -d $DESTDIR/opt/hud/lib              &&
+install -v -m755 -d $DESTDIR/opt/hud/include/nss      &&
+install -v -m755 -d $DESTDIR/opt/hud/bin              &&
+install -v -m755 -d $DESTDIR/opt/hud/lib/pkgconfig    &&
+install -v -m755 Linux*/lib/*.so              $DESTDIR/opt/hud/lib              &&
+install -v -m644 Linux*/lib/{*.chk,libcrmf.a} $DESTDIR/opt/hud/lib              &&
+cp -v -RL {public,private}/nss/*              $DESTDIR/opt/hud/include/nss      &&
+install -v -m755 Linux*/bin/{certutil,nss-config,pk12util} $DESTDIR/opt/hud/bin &&
+install -v -m644 Linux*/lib/pkgconfig/nss.pc  $DESTDIR/opt/hud/lib/pkgconfig
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ nss 3.108 installed to /opt/hud"
+# Configure p11-kit trust module as drop-in replacement if p11-kit is installed
+if [ -f /opt/hud/lib/pkcs11/p11-kit-trust.so ]; then
+    ln -sfv ./pkcs11/p11-kit-trust.so /opt/hud/lib/libnssckbi.so
+fi
+echo "nss 3.115 installed to /opt/hud"
+
+[prerm]
+# No services to stop
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `openjdk`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/o/openjdk/openjdk-24.0.2.huddef` | 24.0.2 | `ae1018ed38a4` | `afee61c71209` | **POOL** |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/openjdk-24.0.2.huddef` | 24.0.2 | `67954d2240c6` | `e22cf1c390e3` | alt |
| `sources/definitions/old/packages/openjdk-24.0.2.huddef` | 24.0.2 | `ae1018ed38a4` | `afee61c71209` | **= POOL** |
| `sources/definitions/old/updated-packages/openjdk-24.0.2.huddef` | 24.0.2 | `ae1018ed38a4` | `afee61c71209` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/openjdk-24.0.2.huddef</code> (63 added, 12 removed)</summary>

```diff
--- pool/main/o/openjdk/openjdk-24.0.2.huddef
+++ sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/openjdk-24.0.2.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - openjdk 24.0.2
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - OpenJDK 24.0.2 (Source Build)
+# Java Development Kit (Source)
+# Fixed: Use OpenJDK's --with-extra-cflags/ldflags for /opt/hud paths
 
 Package: openjdk
@@ -6,24 +7,74 @@
 Architecture: x86_64
 Section: development
-Depends: alsa-lib,java,git,graphviz,ojdk-conf,mercurial,cups,make-ca,harfbuzz,libarchive,zip,libjpeg,xorg7-lib,libpng,which
-Description: OpenJDK-24.0.2
+Depends: java-bin, alsa-lib, cups, cpio, libarchive, which, zip, glib, giflib, harfbuzz, lcms2, libjpeg-turbo, libpng, make-ca
+Description: Open-source Java Development Kit built from source
 Source: https://github.com/openjdk/jdk24u/archive/jdk-24.0.2-ga.tar.gz
 
 [configure]
-bash configure --prefix=/opt/hud --with-boot-jdk=/usr/lib/jvm/java-21-openjdk --disable-warnings-as-errors
+# Add /opt/hud paths for tools
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+
+# Fix build failure with glibc-2.42+
+find src -name *.*pp -exec sed -i 's/uabs(/g_uabs(/' {} \;
+
+# Save and clear MAKEFLAGS
+export MAKEFLAGS_HOLD=$MAKEFLAGS
+unset JAVA_HOME
+unset CLASSPATH
+unset MAKEFLAGS
+
+# Set JAVA_HOME for bootstrap JDK
+export JAVA_HOME=/opt/jdk
+export PATH="${JAVA_HOME}/bin:${PATH}"
+
+bash configure --enable-unlimited-crypto    \
+               --disable-warnings-as-errors \
+               --with-stdc++lib=dynamic     \
+               --with-giflib=system         \
+               --with-harfbuzz=system       \
+               --with-lcms=system           \
+               --with-libjpeg=system        \
+               --with-libpng=system         \
+               --with-zlib=system           \
+               --with-version-build="12"    \
+               --with-version-pre=""        \
+               --with-version-opt=""        \
+               --with-jobs=$(nproc)         \
+               --with-cacerts-file=/etc/pki/tls/java/cacerts \
+               --with-extra-cflags="-I/opt/hud/include" \
+               --with-extra-cxxflags="-I/opt/hud/include" \
+               --with-extra-ldflags="-L/opt/hud/lib -L/opt/hud/lib64"
 
 [build]
+export PATH="/opt/hud/bin:/opt/hud/sbin:/opt/jdk/bin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make images
 
 [install]
-mkdir -p $DESTDIR/opt/hud/lib/jvm && cp -a build/*/images/jdk/* $DESTDIR/opt/hud/lib/jvm/
+install -vdm755 $DESTDIR/opt/jdk-24.0.2+12
+cp -Rv build/*/images/jdk/* $DESTDIR/opt/jdk-24.0.2+12/
+
+for s in 16 24 32 48; do
+  install -vDm644 src/java.desktop/unix/classes/sun/awt/X11/java-icon${s}.png \
+                  $DESTDIR/usr/share/icons/hicolor/${s}x${s}/apps/java.png 2>/dev/null || true
+done
 
 [postinst]
-ldconfig 2>/dev/null || true
-echo "openjdk 24.0.2 installed to /opt/hud"
+chown -R root:root /opt/jdk-24.0.2+12
+ln -sfv jdk-24.0.2+12 /opt/jdk
 
-[prerm]
-# Stop service if running
+cat > /etc/profile.d/openjdk.sh << "EOF"
+JAVA_HOME=/opt/jdk
+case ":$PATH:" in
+    *":$JAVA_HOME/bin:"*) ;;
+    *) PATH="$JAVA_HOME/bin:$PATH" ;;
+esac
+export JAVA_HOME PATH
+_JAVA_OPTIONS="-XX:-UsePerfData"
+export _JAVA_OPTIONS
+EOF
 
-[postrm]
-ldconfig 2>/dev/null || true
+ln -sfv /etc/pki/tls/java/cacerts /opt/jdk/lib/security/cacerts 2>/dev/null || true
+echo "✓ OpenJDK 24.0.2 installed to /opt/jdk-24.0.2+12"
```

</details>


### `openldap`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/o/openldap/openldap-2.6.10.huddef` | 2.6.10 | `27c161fcb4cf` | `8ec6db72e26a` | **POOL** |
| `sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/openldap-2.6.10.huddef` | 2.6.10 | `e18eed876c1b` | `5d00f7ca11f1` | alt |
| `sources/definitions/old/packages/openldap-2.6.10.huddef` | 2.6.10 | `27c161fcb4cf` | `8ec6db72e26a` | **= POOL** |
| `sources/definitions/old/updated-packages/openldap-2.6.10.huddef` | 2.6.10 | `27c161fcb4cf` | `8ec6db72e26a` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/openldap-2.6.10.huddef</code> (97 added, 21 removed)</summary>

```diff
--- pool/main/o/openldap/openldap-2.6.10.huddef
+++ sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/openldap-2.6.10.huddef
@@ -1,38 +1,114 @@
-# HUD Package Definition - openldap 2.6.10
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - OpenLDAP 2.6.10
+# Lightweight Directory Access Protocol
+# Fixed: Properly locate Cyrus SASL in /opt/hud
 
 Package: openldap
 Version: 2.6.10
 Architecture: x86_64
-Section: security
-Depends: mariadb,gnutls,cyrus-sasl,bootscripts
-Description: OpenLDAP-2.6.10
-Source: https://anduin.linuxfromscratch.org/BLFS/bdb/db-5.3.28.tar.gz
-Service: slapd
+Section: server
+Depends: cyrus-sasl, openssl
+Description: Open source implementation of Lightweight Directory Access Protocol
+Source: https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.10.tgz
 
 [configure]
-./configure --prefix=/opt/hud --sysconfdir=/opt/hud/etc --enable-dynamic --enable-slapd --enable-modules
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export CFLAGS="${CFLAGS} -I/opt/hud/include -I/opt/hud/include/sasl"
+export CPPFLAGS="${CPPFLAGS} -I/opt/hud/include -I/opt/hud/include/sasl"
+export LDFLAGS="${LDFLAGS} -L/opt/hud/lib -L/opt/hud/lib64 -Wl,-rpath,/opt/hud/lib"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+
+# Regenerate configure
+autoreconf -fiv 2>/dev/null || autoconf 2>/dev/null || true
+
+./configure --prefix=/opt/hud              \
+            --sysconfdir=/opt/hud/etc      \
+            --localstatedir=/var           \
+            --libexecdir=/opt/hud/lib      \
+            --disable-static               \
+            --disable-debug                \
+            --with-tls=openssl             \
+            --with-cyrus-sasl              \
+            --without-systemd              \
+            --enable-dynamic               \
+            --enable-crypt                 \
+            --enable-spasswd               \
+            --enable-slapd                 \
+            --enable-modules               \
+            --enable-rlookups              \
+            --enable-backends=mod          \
+            --disable-sql                  \
+            --disable-wt                   \
+            --enable-overlays=mod          \
+            CPPFLAGS="-I/opt/hud/include -I/opt/hud/include/sasl" \
+            LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
 
 [build]
-make -j$(nproc)
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+make depend
+make
 
 [install]
-make install &&
+make DESTDIR=$DESTDIR install
 
-sed -e "s/\.la/.so/" -i /etc/openldap/slapd.{conf,ldif}{,.default} &&
+# Fix .la files to use .so
+sed -e "s/\.la/.so/" -i $DESTDIR/opt/hud/etc/openldap/slapd.conf 2>/dev/null || true
+sed -e "s/\.la/.so/" -i $DESTDIR/opt/hud/etc/openldap/slapd.ldif 2>/dev/null || true
 
-install -v -dm700 -o ldap -g ldap /var/lib/openldap     &&
+# Create required directories
+install -vdm700 $DESTDIR/var/lib/openldap
+install -vdm700 $DESTDIR/opt/hud/etc/openldap/slapd.d
 
-install -v -dm700 -o ldap -g ldap /etc/openldap/slap
+# Install documentation
+install -vdm755 $DESTDIR/opt/hud/share/doc/openldap-2.6.10
+cp -vfr doc/{drafts,rfc,guide} $DESTDIR/opt/hud/share/doc/openldap-2.6.10/ 2>/dev/null || true
+
+# Install systemd service
+install -vdm755 $DESTDIR/etc/systemd/system
+cat > $DESTDIR/etc/systemd/system/slapd.service << 'SVCEOF'
+[Unit]
+Description=OpenLDAP Server Daemon
+After=network.target
+
+[Service]
+Type=forking
+PIDFile=/run/slapd/slapd.pid
+Environment="SLAPD_URLS=ldap:/// ldapi:///"
+Environment="SLAPD_OPTIONS=-F /opt/hud/etc/openldap/slapd.d"
+ExecStartPre=/bin/mkdir -p /run/slapd
+ExecStartPre=/bin/chown ldap:ldap /run/slapd
+ExecStart=/opt/hud/lib/slapd -u ldap -g ldap -h "${SLAPD_URLS}" $SLAPD_OPTIONS
+ExecReload=/bin/kill -HUP $MAINPID
+
+[Install]
+WantedBy=multi-user.target
+SVCEOF
 
 [postinst]
-ldconfig 2>/dev/null || true
-echo "openldap 2.6.10 installed to /opt/hud"
+ldconfig
 
-[prerm]
-# Stop service if running
-systemctl stop hud-slapd 2>/dev/null || true
-systemctl disable hud-slapd 2>/dev/null || true
+# Create ldap user/group if they don't exist
+getent group ldap >/dev/null || groupadd -g 83 ldap
+getent passwd ldap >/dev/null || useradd -c "OpenLDAP Daemon Owner" \
+    -d /var/lib/openldap -u 83 -g ldap -s /bin/false ldap
 
-[postrm]
-ldconfig 2>/dev/null || true
+# Set proper ownership
+install -vdm700 -o ldap -g ldap /var/lib/openldap 2>/dev/null || true
+install -vdm700 -o ldap -g ldap /opt/hud/etc/openldap/slapd.d 2>/dev/null || true
+chmod 640 /opt/hud/etc/openldap/slapd.conf 2>/dev/null || true
+chmod 640 /opt/hud/etc/openldap/slapd.ldif 2>/dev/null || true
+chown root:ldap /opt/hud/etc/openldap/slapd.conf 2>/dev/null || true
+chown root:ldap /opt/hud/etc/openldap/slapd.ldif 2>/dev/null || true
+
+# Reload systemd
+systemctl daemon-reload 2>/dev/null || true
+
+echo "✓ OpenLDAP 2.6.10 installed to /opt/hud"
+echo ""
+echo "To start slapd:"
+echo "  systemctl enable --now slapd"
+echo ""
+echo "Configuration files:"
+echo "  Client: /opt/hud/etc/openldap/ldap.conf"
+echo "  Server: /opt/hud/etc/openldap/slapd.conf"
```

</details>


### `p11-kit`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/p11-kit/p11-kit-0.25.5.huddef` | 0.25.5 | `20db8acb3a46` | `8537792daf18` | **POOL** |
| `sources/definitions/old/1 Feb 2026/cups-huddef-packages/p11-kit-0.25.5.huddef` | 0.25.5 | `55b7cc24b1d9` | `262047d68225` | alt |
| `sources/definitions/old/packages/p11-kit-0.25.5.huddef` | 0.25.5 | `538a17b34c92` | `99657752bb37` | alt |
| `sources/definitions/old/updated-packages/p11-kit-0.25.5.huddef` | 0.25.5 | `20db8acb3a46` | `8537792daf18` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/cups-huddef-packages/p11-kit-0.25.5.huddef</code> (23 added, 33 removed)</summary>

```diff
--- pool/main/p/p11-kit/p11-kit-0.25.5.huddef
+++ sources/definitions/old/1 Feb 2026/cups-huddef-packages/p11-kit-0.25.5.huddef
@@ -1,4 +1,5 @@
 # HUD Package Definition - p11-kit 0.25.5
-# Based on BLFS 12.4 documentation
+# PKCS#11 Module Manager
+# Library and tools for managing PKCS#11 modules
 
 Package: p11-kit
@@ -6,48 +7,37 @@
 Architecture: x86_64
 Section: security
-Depends: libtasn1
-Description: Library to load and enumerate PKCS#11 modules for cryptographic token interface
+Depends: libtasn1, libffi
+Description: Library dealing with loading and enumerating PKCS#11 modules and trust policy
 Source: https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz
 
 [configure]
-# Prepare the distribution specific anchor hook
-sed '20,$ d' -i trust/trust-extract-compat &&
-cat >> trust/trust-extract-compat << "EOF"
-# Copy existing anchor modifications to /etc/ssl/local
-/usr/libexec/make-ca/copy-trust-modifications
+# Create link for trust store
+ln -sf /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true
 
-# Update trust stores
-/usr/sbin/make-ca -r
-EOF
+mkdir -p build
+cd build
 
-# Create build directory and run meson
-mkdir -p p11-build &&
-cd p11-build &&
-meson setup ..            \
-      --prefix=/opt/hud   \
-      --buildtype=release \
-      -D trust_paths=/etc/pki/anchors
+meson setup ..                        \
+    --prefix=/opt/hud                 \
+    --buildtype=release               \
+    -D trust_paths=/etc/pki/anchors
 
 [build]
-cd p11-build &&
+cd build
 ninja
 
 [install]
-cd p11-build &&
-DESTDIR=$DESTDIR ninja install &&
+cd build
+DESTDIR=$DESTDIR ninja install
+
+# Create necessary symlinks
 ln -sfv /opt/hud/libexec/p11-kit/trust-extract-compat \
-        $DESTDIR/opt/hud/bin/update-ca-certificates
+        $DESTDIR/opt/hud/bin/update-ca-certificates 2>/dev/null || true
 
 [postinst]
+# Link p11-kit trust for ca-certificates compatibility
+ln -sfv /opt/hud/libexec/p11-kit/trust-extract-compat \
+        /opt/hud/bin/update-ca-certificates 2>/dev/null || true
+
 ldconfig 2>/dev/null || true
-# Create symlink for NSS compatibility if NSS is installed
-if [ -d /usr/lib/pkcs11 ]; then
-    ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so 2>/dev/null || true
-fi
-echo "p11-kit 0.25.5 installed to /opt/hud"
-
-[prerm]
-# No services to stop
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ p11-kit 0.25.5 installed to /opt/hud"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/p11-kit-0.25.5.huddef</code> (8 added, 32 removed)</summary>

```diff
--- pool/main/p/p11-kit/p11-kit-0.25.5.huddef
+++ sources/definitions/old/packages/p11-kit-0.25.5.huddef
@@ -1,52 +1,28 @@
 # HUD Package Definition - p11-kit 0.25.5
-# Based on BLFS 12.4 documentation
+# Auto-generated for oVirt infrastructure
 
 Package: p11-kit
 Version: 0.25.5
 Architecture: x86_64
-Section: security
-Depends: libtasn1
-Description: Library to load and enumerate PKCS#11 modules for cryptographic token interface
+Section: misc
+Depends: gtk-doc,libtasn1,make-ca,nss
+Description: p11-kit-0.25.5
 Source: https://github.com/p11-glue/p11-kit/releases/download/0.25.5/p11-kit-0.25.5.tar.xz
 
 [configure]
-# Prepare the distribution specific anchor hook
-sed '20,$ d' -i trust/trust-extract-compat &&
-cat >> trust/trust-extract-compat << "EOF"
-# Copy existing anchor modifications to /etc/ssl/local
-/usr/libexec/make-ca/copy-trust-modifications
-
-# Update trust stores
-/usr/sbin/make-ca -r
-EOF
-
-# Create build directory and run meson
-mkdir -p p11-build &&
-cd p11-build &&
-meson setup ..            \
-      --prefix=/opt/hud   \
-      --buildtype=release \
-      -D trust_paths=/etc/pki/anchors
+./configure --prefix=/opt/hud
 
 [build]
-cd p11-build &&
-ninja
+make -j$(nproc)
 
 [install]
-cd p11-build &&
-DESTDIR=$DESTDIR ninja install &&
-ln -sfv /opt/hud/libexec/p11-kit/trust-extract-compat \
-        $DESTDIR/opt/hud/bin/update-ca-certificates
+make install
 
 [postinst]
 ldconfig 2>/dev/null || true
-# Create symlink for NSS compatibility if NSS is installed
-if [ -d /usr/lib/pkcs11 ]; then
-    ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so 2>/dev/null || true
-fi
 echo "p11-kit 0.25.5 installed to /opt/hud"
 
 [prerm]
-# No services to stop
+# Stop service if running
 
 [postrm]
```

</details>


### `pcre2`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/pcre2/pcre2-10.45.huddef` | 10.45 | `acd80c00ddc6` | `231b87e04eca` | **POOL** |
| `sources/definitions/old/0/pcre2-10.45.huddef` | 10.45 | `68242473c1b3` | `8c07e5aa3e11` | alt |
| `sources/definitions/old/packages/pcre2-10.45.huddef` | 10.45 | `380254002729` | `b19fc2afad30` | alt |
| `sources/definitions/old/pcre2-10.45.huddef` | 10.45 | `acd80c00ddc6` | `231b87e04eca` | **= POOL** |
| `sources/definitions/old/updated-packages/pcre2-10.45.huddef` | 10.45 | `acd80c00ddc6` | `231b87e04eca` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/pcre2-10.45.huddef</code> (5 added, 21 removed)</summary>

```diff
--- pool/main/p/pcre2/pcre2-10.45.huddef
+++ sources/definitions/old/0/pcre2-10.45.huddef
@@ -1,34 +1,18 @@
 # HUD Package Definition - pcre2 10.45
 # Perl Compatible Regular Expressions
-
 Package: pcre2
 Version: 10.45
 Architecture: x86_64
 Section: libraries
-Depends: zlib,bzip2
-Description: Perl Compatible Regular Expressions library (version 2)
+Depends:
+Description: Perl Compatible Regular Expressions library version 2
 Source: https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.45/pcre2-10.45.tar.bz2
-
 [configure]
-./configure \
-    --prefix=/opt/hud \
-    --enable-unicode \
-    --enable-jit \
-    --enable-pcre2-16 \
-    --enable-pcre2-32 \
-    --enable-pcre2grep-libz \
-    --enable-pcre2grep-libbz2 \
-    --disable-static \
-    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
-    CPPFLAGS="-I/opt/hud/include"
-
+./configure --prefix=/opt/hud --enable-unicode --enable-jit --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ pcre2 10.45 installed to /opt/hud"
-
+/sbin/ldconfig
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/pcre2-10.45.huddef</code> (0 added, 1 removed)</summary>

```diff
--- pool/main/p/pcre2/pcre2-10.45.huddef
+++ sources/definitions/old/packages/pcre2-10.45.huddef
@@ -32,3 +32,2 @@
 ldconfig 2>/dev/null || true
 echo "✓ pcre2 10.45 installed to /opt/hud"
-
```

</details>


### `pixman`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/pixman/pixman-0.44.2.huddef` | 0.44.2 | `ae6b28bbcdad` | `3d54d512f899` | **POOL** |
| `pool/main/p/pixman/pixman-0.46.4.huddef` | 0.46.4 | `a7127d0178d5` | `263741976f82` | **POOL** |
| `sources/definitions/old/0/pixman-0.44.2.huddef` | 0.44.2 | `ae6b28bbcdad` | `3d54d512f899` | **= POOL** |
| `sources/definitions/old/packages/pixman-0.46.4.huddef` | 0.46.4 | `e2eccd651dd3` | `fc8f8894b8e8` | alt |
| `sources/definitions/old/updated-packages/pixman-0.44.2.huddef` | 0.44.2 | `ae6b28bbcdad` | `3d54d512f899` | **= POOL** |
| `sources/definitions/old/updated-packages/pixman-0.46.4.huddef` | 0.46.4 | `e2eccd651dd3` | `fc8f8894b8e8` | alt |
| `sources/definitions/qemu-huddef/pixman-0.46.4.huddef` | 0.46.4 | `a7127d0178d5` | `263741976f82` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/pixman-0.46.4.huddef</code> (22 added, 15 removed)</summary>

```diff
--- pool/main/p/pixman/pixman-0.44.2.huddef
+++ sources/definitions/old/packages/pixman-0.46.4.huddef
@@ -1,22 +1,29 @@
-# HUD Package Definition - pixman 0.44.2
-# Low-level pixel manipulation library
+# HUD Package Definition - pixman 0.46.4
+# Auto-generated for oVirt infrastructure
+
 Package: pixman
-Version: 0.44.2
+Version: 0.46.4
 Architecture: x86_64
 Section: graphics
-Depends:
-Description: Low-level pixel manipulation library
-Source: https://www.cairographics.org/releases/pixman-0.44.2.tar.gz
+Depends: 
+Description: Pixman-0.46.4
+Source: https://www.cairographics.org/releases/pixman-0.46.4.tar.gz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ pixman 0.44.2 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "pixman 0.46.4 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/qemu-huddef/pixman-0.46.4.huddef</code> (14 added, 8 removed)</summary>

```diff
--- pool/main/p/pixman/pixman-0.44.2.huddef
+++ sources/definitions/qemu-huddef/pixman-0.46.4.huddef
@@ -1,16 +1,22 @@
-# HUD Package Definition - pixman 0.44.2
-# Low-level pixel manipulation library
+# HUD Package Definition - Pixman 0.46.4
+# Low-level pixel manipulation library (required for QEMU)
+# Updates installed 0.44.2 to required 0.46.4
 Package: pixman
-Version: 0.44.2
+Version: 0.46.4
 Architecture: x86_64
 Section: graphics
-Depends:
-Description: Low-level pixel manipulation library
-Source: https://www.cairographics.org/releases/pixman-0.44.2.tar.gz
+Depends: glib
+Description: Low-level pixel manipulation library providing image compositing and trapezoid rasterization
+Source: https://www.cairographics.org/releases/pixman-0.46.4.tar.gz
 [configure]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 mkdir -p build
 cd build
 meson setup --prefix=/opt/hud --buildtype=release ..
 [build]
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 cd build
 ninja
@@ -19,4 +25,4 @@
 DESTDIR=$DESTDIR ninja install
 [postinst]
-echo "✓ pixman 0.44.2 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig
+echo "✓ Pixman 0.46.4 installed to /opt/hud"
```

</details>


### `polkit`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/polkit/polkit-126.huddef` | 126 | `7ea4046c08ea` | `65ef57640419` | **POOL** |
| `sources/definitions/old/1 Feb 2026/polkit-126.huddef` | 126 | `5588543cde6b` | `cbe5e6089843` | alt |
| `sources/definitions/old/packages/polkit-125.huddef` | 125 | `ba6a593cceeb` | `9567542c5b8c` | alt |
| `sources/definitions/old/packages/polkit-126.huddef` | 126 | `7ea4046c08ea` | `65ef57640419` | **= POOL** |
| `sources/definitions/old/updated-packages/polkit-126.huddef` | 126 | `7ea4046c08ea` | `65ef57640419` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/polkit-126.huddef</code> (73 added, 39 removed)</summary>

```diff
--- pool/main/p/polkit/polkit-126.huddef
+++ sources/definitions/old/1 Feb 2026/polkit-126.huddef
@@ -1,4 +1,6 @@
-# HUD Package Definition - polkit 126
-# Authorization framework
+# HUD Package Definition - Polkit 126
+# Authorization Toolkit
+# Defines and handles authorizations for unprivileged processes
+# Fixed: Disabled gobject-introspection (optional dependency)
 
 Package: polkit
@@ -6,48 +8,80 @@
 Architecture: x86_64
 Section: security
-Depends: glib2,expat,linux-pam,duktape,elogind
-Description: Application-level authorization toolkit
-Source: https://gitlab.freedesktop.org/polkit/polkit/-/archive/126/polkit-126.tar.gz
+Depends: duktape, glib, systemd, dbus, libxslt
+Description: Toolkit for defining and handling authorizations between unprivileged and privileged processes
+Source: https://github.com/polkit-org/polkit/archive/126/polkit-126.tar.gz
 
 [configure]
-mkdir -p build && cd build && meson setup .. \
-    --prefix=/opt/hud \
-    --sysconfdir=/opt/hud/etc \
-    -Dman=false \
-    -Dexamples=false \
-    -Dgtk_doc=false \
-    -Dintrospection=false \
-    -Dtests=false \
-    -Dsession_tracking=libelogind \
-    -Djs_engine=duktape \
-    -Dsystemdsystemunitdir=/opt/hud/lib/systemd/system
+mkdir -p build
+cd build
+
+# Set up environment for finding libraries in /opt/hud
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LIBRARY_PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+export CFLAGS="-I/opt/hud/include ${CFLAGS}"
+export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 ${LDFLAGS}"
+
+# Determine auth framework: PAM if available, otherwise shadow
+AUTH_FW="shadow"
+if pkg-config --exists pam 2>/dev/null; then
+    AUTH_FW="pam"
+elif [ -f /opt/hud/lib/libpam.so ] || [ -f /usr/lib/libpam.so ]; then
+    # PAM exists but no pkg-config file - create one
+    if [ -f /opt/hud/lib/libpam.so ] && [ ! -f /opt/hud/lib/pkgconfig/pam.pc ]; then
+        mkdir -p /opt/hud/lib/pkgconfig
+        cat > /opt/hud/lib/pkgconfig/pam.pc << 'PAMPC'
+prefix=/opt/hud
+exec_prefix=${prefix}
+libdir=${prefix}/lib
+includedir=${prefix}/include
+
+Name: pam
+Description: Linux PAM (Pluggable Authentication Modules)
+Version: 1.7.1
+Libs: -L${libdir} -lpam
+Cflags: -I${includedir}
+PAMPC
+        AUTH_FW="pam"
+    fi
+fi
+
+echo "Using authentication framework: ${AUTH_FW}"
+
+meson setup ..                     \
+    --prefix=/opt/hud              \
+    --buildtype=release            \
+    --pkg-config-path=/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig \
+    -D man=false                   \
+    -D session_tracking=logind     \
+    -D tests=false                 \
+    -D gtk_doc=false               \
+    -D introspection=false         \
+    -D examples=false              \
+    -D authfw=${AUTH_FW}
 
 [build]
-cd build && ninja -j$(nproc)
+cd build
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+ninja
 
 [install]
-cd build && DESTDIR=$DESTDIR ninja install
-# Create polkitd user setup script
-mkdir -p $DESTDIR/opt/hud/share/hud/setup
-cat > $DESTDIR/opt/hud/share/hud/setup/polkit-setup.sh << 'POLKITSETUP'
-#!/bin/bash
-getent group polkitd >/dev/null || groupadd -r polkitd
-getent passwd polkitd >/dev/null || useradd -r -g polkitd -d / -s /sbin/nologin -c "PolicyKit Daemon" polkitd
-POLKITSETUP
-chmod +x $DESTDIR/opt/hud/share/hud/setup/polkit-setup.sh
+cd build
+DESTDIR=$DESTDIR ninja install
 
 [postinst]
+# Create polkitd user and group for daemon ownership
+getent group polkitd >/dev/null || groupadd -fg 27 polkitd
+getent passwd polkitd >/dev/null || useradd -c "PolicyKit Daemon Owner" \
+    -d /etc/polkit-1 -u 27 -g polkitd -s /bin/false polkitd
+
+# Set proper ownership on polkit directories
+chown -R polkitd:polkitd /opt/hud/lib/polkit-1 2>/dev/null || true
+
+# Create polkit rules directory
+mkdir -p /etc/polkit-1/rules.d
+
 ldconfig 2>/dev/null || true
-if [ -x /opt/hud/share/hud/setup/polkit-setup.sh ]; then
-    /opt/hud/share/hud/setup/polkit-setup.sh 2>/dev/null || true
-fi
-echo "✓ polkit 126 installed to /opt/hud"
-
-[prerm]
-systemctl stop hud-polkit 2>/dev/null || true
-
-[postrm]
-ldconfig 2>/dev/null || true
-
-[service]
-polkit
+echo "✓ Polkit 126 installed to /opt/hud"
+echo "  Note: Requires systemd-logind at runtime for session tracking"
+echo "  Note: Install a polkit authentication agent for graphical environments"
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/polkit-125.huddef</code> (13 added, 34 removed)</summary>

```diff
--- pool/main/p/polkit/polkit-126.huddef
+++ sources/definitions/old/packages/polkit-125.huddef
@@ -1,53 +1,32 @@
-# HUD Package Definition - polkit 126
-# Authorization framework
+# HUD Package Definition - polkit 125
+# Auto-generated for oVirt infrastructure
 
 Package: polkit
-Version: 126
+Version: 125
 Architecture: x86_64
 Section: security
-Depends: glib2,expat,linux-pam,duktape,elogind
-Description: Application-level authorization toolkit
-Source: https://gitlab.freedesktop.org/polkit/polkit/-/archive/126/polkit-126.tar.gz
+Depends: glib2,expat,linux-pam,duktape,gobject-introspection
+Description: PolicyKit Authorization Framework
+Source: https://gitlab.freedesktop.org/polkit/polkit/-/archive/125/polkit-125.tar.gz
+Service: polkit
 
 [configure]
-mkdir -p build && cd build && meson setup .. \
-    --prefix=/opt/hud \
-    --sysconfdir=/opt/hud/etc \
-    -Dman=false \
-    -Dexamples=false \
-    -Dgtk_doc=false \
-    -Dintrospection=false \
-    -Dtests=false \
-    -Dsession_tracking=libelogind \
-    -Djs_engine=duktape \
-    -Dsystemdsystemunitdir=/opt/hud/lib/systemd/system
+meson setup build --prefix=/opt/hud -Dsession_tracking=libelogind -Dsystemdsystemunitdir=/opt/hud/lib/systemd/system
 
 [build]
-cd build && ninja -j$(nproc)
+ninja -C build
 
 [install]
-cd build && DESTDIR=$DESTDIR ninja install
-# Create polkitd user setup script
-mkdir -p $DESTDIR/opt/hud/share/hud/setup
-cat > $DESTDIR/opt/hud/share/hud/setup/polkit-setup.sh << 'POLKITSETUP'
-#!/bin/bash
-getent group polkitd >/dev/null || groupadd -r polkitd
-getent passwd polkitd >/dev/null || useradd -r -g polkitd -d / -s /sbin/nologin -c "PolicyKit Daemon" polkitd
-POLKITSETUP
-chmod +x $DESTDIR/opt/hud/share/hud/setup/polkit-setup.sh
+DESTDIR=$DESTDIR ninja -C build install
 
 [postinst]
 ldconfig 2>/dev/null || true
-if [ -x /opt/hud/share/hud/setup/polkit-setup.sh ]; then
-    /opt/hud/share/hud/setup/polkit-setup.sh 2>/dev/null || true
-fi
-echo "✓ polkit 126 installed to /opt/hud"
+echo "polkit 125 installed to /opt/hud"
 
 [prerm]
+# Stop service if running
 systemctl stop hud-polkit 2>/dev/null || true
+systemctl disable hud-polkit 2>/dev/null || true
 
 [postrm]
 ldconfig 2>/dev/null || true
-
-[service]
-polkit
```

</details>


### `popt`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/popt/popt-1.19.huddef` | 1.19 | `b7dc51ee4d61` | `b31a3d7e3b46` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/popt-1.19.huddef` | 1.19 | `b7dc51ee4d61` | `b31a3d7e3b46` | **= POOL** |
| `sources/definitions/old/packages/popt-1.19.huddef` | 1.19 | `abffb52c132c` | `7257f4344154` | alt |
| `sources/definitions/old/updated-packages/popt-1.19.huddef` | 1.19 | `abffb52c132c` | `7257f4344154` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/popt-1.19.huddef</code> (9 added, 20 removed)</summary>

```diff
--- pool/main/p/popt/popt-1.19.huddef
+++ sources/definitions/old/packages/popt-1.19.huddef
@@ -1,5 +1,4 @@
-# HUD Package Definition - Popt 1.19
-# Command-line option parsing library
-# Foundational dependency for newt and other packages
+# HUD Package Definition - popt 1.19
+# Command line parsing library
 
 Package: popt
@@ -8,24 +7,14 @@
 Section: libraries
 Depends:
-Description: Library for parsing command-line options
-Source: https://ftp.osuosl.org/pub/rpm/popt/releases/popt-1.x/popt-1.19.tar.gz
+Description: Command line option parsing library
+Source: http://ftp.rpm.org/popt/releases/popt-1.x/popt-1.19.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-./configure --prefix=/opt/hud \
-            --disable-static
+./configure \
+    --prefix=/opt/hud \
+    --disable-static
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make -j$(nproc)
-
-[check]
-make check
 
 [install]
@@ -33,4 +22,4 @@
 
 [postinst]
-ldconfig
-echo "✓ Popt 1.19 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "✓ popt 1.19 installed to /opt/hud"
```

</details>


### `postgresql`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/postgresql/postgresql-17.6.huddef` | 17.6 | `8f5183721bcd` | `7bc780e5b234` | **POOL** |
| `sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/postgresql-17.6.huddef` | 17.6 | `6c2d07fc9da1` | `8bba6922c50b` | alt |
| `sources/definitions/old/packages/postgresql-17.6.huddef` | 17.6 | `8f5183721bcd` | `7bc780e5b234` | **= POOL** |
| `sources/definitions/old/updated-packages/postgresql-17.6.huddef` | 17.6 | `8f5183721bcd` | `7bc780e5b234` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/postgresql-17.6.huddef</code> (127 added, 16 removed)</summary>

```diff
--- pool/main/p/postgresql/postgresql-17.6.huddef
+++ sources/definitions/old/1 Feb 2026/postgresql-huddef-bundle/postgresql-huddef-bundle/postgresql-17.6.huddef
@@ -1,4 +1,5 @@
-# HUD Package Definition - postgresql 17.6
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - PostgreSQL 17.6
+# Advanced Object-Relational Database Management System
+# Full-featured build with systemd service
 
 Package: postgresql
@@ -6,27 +7,137 @@
 Architecture: x86_64
 Section: databases
-Depends: 
-Description: PostgreSQL-17.6
+Depends: openssl, icu, libxml2, libxslt
+Description: Advanced open source object-relational database system
 Source: https://ftp.postgresql.org/pub/source/v17.6/postgresql-17.6.tar.bz2
-Service: postgresql
 
 [configure]
-./configure --prefix=/opt/hud --with-openssl --with-libxml --enable-thread-safety
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
+export CFLAGS="${CFLAGS} -I/opt/hud/include"
+export CPPFLAGS="${CPPFLAGS} -I/opt/hud/include"
+export LDFLAGS="${LDFLAGS} -L/opt/hud/lib -L/opt/hud/lib64 -Wl,-rpath,/opt/hud/lib"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+
+# Change default socket directory from /tmp to /run/postgresql
+sed -i '/DEFAULT_PGSOCKET_DIR/s@/tmp@/run/postgresql@' src/include/pg_config_manual.h
+
+./configure --prefix=/opt/hud                          \
+            --sysconfdir=/opt/hud/etc                  \
+            --docdir=/opt/hud/share/doc/postgresql-17.6 \
+            --with-openssl                             \
+            --with-icu                                 \
+            --with-libxml                              \
+            --with-libxslt                             \
+            --with-system-tzdata=/usr/share/zoneinfo  \
+            --enable-thread-safety
 
 [build]
-make -j$(nproc)
+export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
+export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+make
+
+# Build contrib modules (optional but recommended)
+make -C contrib
 
 [install]
-make install
+make DESTDIR=$DESTDIR install
+make DESTDIR=$DESTDIR install-docs
+
+# Install contrib modules
+make -C contrib DESTDIR=$DESTDIR install
+
+# Create directories for data and runtime
+install -vdm700 $DESTDIR/srv/pgsql/data
+install -vdm755 $DESTDIR/run/postgresql
+
+# Install systemd service
+install -vdm755 $DESTDIR/etc/systemd/system
+cat > $DESTDIR/etc/systemd/system/postgresql.service << 'SVCEOF'
+[Unit]
+Description=PostgreSQL database server
+Documentation=man:postgres(1)
+After=network.target
+
+[Service]
+Type=notify
+User=postgres
+Group=postgres
+
+# Data directory
+Environment=PGDATA=/srv/pgsql/data
+
+# Runtime directory
+RuntimeDirectory=postgresql
+RuntimeDirectoryMode=0755
+
+# Paths
+Environment=PATH=/opt/hud/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
+Environment=LD_LIBRARY_PATH=/opt/hud/lib
+
+# Pre-start: create runtime directory
+ExecStartPre=/bin/mkdir -p /run/postgresql
+ExecStartPre=/bin/chown postgres:postgres /run/postgresql
+
+# Start PostgreSQL
+ExecStart=/opt/hud/bin/postgres -D ${PGDATA}
+
+# Reload configuration
+ExecReload=/bin/kill -HUP $MAINPID
+
+# Stop PostgreSQL (smart shutdown)
+KillMode=mixed
+KillSignal=SIGINT
+TimeoutSec=infinity
+
+[Install]
+WantedBy=multi-user.target
+SVCEOF
+
+# Install environment profile
+install -vdm755 $DESTDIR/etc/profile.d
+cat > $DESTDIR/etc/profile.d/postgresql.sh << 'ENVEOF'
+# PostgreSQL environment
+PGSQL_HOME=/opt/hud
+export PATH="${PGSQL_HOME}/bin:${PATH}"
+export LD_LIBRARY_PATH="${PGSQL_HOME}/lib:${LD_LIBRARY_PATH}"
+export PGDATA=/srv/pgsql/data
+ENVEOF
 
 [postinst]
-ldconfig 2>/dev/null || true
-echo "postgresql 17.6 installed to /opt/hud"
+ldconfig
 
-[prerm]
-# Stop service if running
-systemctl stop hud-postgresql 2>/dev/null || true
-systemctl disable hud-postgresql 2>/dev/null || true
+# Create postgres user/group if they don't exist
+getent group postgres >/dev/null || groupadd -g 41 postgres
+getent passwd postgres >/dev/null || useradd -c "PostgreSQL Server" \
+    -g postgres -d /srv/pgsql/data -u 41 -s /bin/bash postgres
 
-[postrm]
-ldconfig 2>/dev/null || true
+# Set proper ownership
+install -vdm700 -o postgres -g postgres /srv/pgsql/data 2>/dev/null || true
+install -vdm755 -o postgres -g postgres /run/postgresql 2>/dev/null || true
+chown -Rv postgres:postgres /srv/pgsql 2>/dev/null || true
+
+# Reload systemd
+systemctl daemon-reload 2>/dev/null || true
+
+echo "✓ PostgreSQL 17.6 installed to /opt/hud"
+echo ""
+echo "=== Quick Start Guide ==="
+echo ""
+echo "1. Initialize the database cluster:"
+echo "   su - postgres -c '/opt/hud/bin/initdb -D /srv/pgsql/data'"
+echo ""
+echo "2. Start PostgreSQL using systemd:"
+echo "   systemctl enable --now postgresql"
+echo ""
+echo "   Or manually:"
+echo "   su - postgres -c '/opt/hud/bin/pg_ctl -D /srv/pgsql/data -l /srv/pgsql/data/logfile start'"
+echo ""
+echo "3. Create a database:"
+echo "   su - postgres -c '/opt/hud/bin/createdb mydb'"
+echo ""
+echo "4. Connect with psql:"
+echo "   su - postgres -c '/opt/hud/bin/psql mydb'"
+echo ""
+echo "5. Stop PostgreSQL:"
+echo "   systemctl stop postgresql"
+echo "   # Or: su - postgres -c '/opt/hud/bin/pg_ctl -D /srv/pgsql/data stop'"
```

</details>


### `qemu`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/q/qemu/qemu-10.0.3.huddef` | 10.0.3 | `7460dd0acd12` | `579be1ffa2c1` | **POOL** |
| `sources/definitions/13 Feb 2026/qemu-10.0.3.huddef` | 10.0.3 | `7460dd0acd12` | `579be1ffa2c1` | **= POOL** |
| `sources/definitions/libvirt_9feb_2026/qemu-10.0.3.huddef` | 10.0.3 | `7460dd0acd12` | `579be1ffa2c1` | **= POOL** |
| `sources/definitions/old/packages/qemu-10.0.3.huddef` | 10.0.3 | `4ee32460275d` | `57deaa4f0f8d` | alt |
| `sources/definitions/old/updated-packages/qemu-10.0.3.huddef` | 10.0.3 | `4ee32460275d` | `57deaa4f0f8d` | alt |
| `sources/definitions/qemu-huddef/qemu-10.0.3.huddef` | 10.0.3 | `b55e95dac6dc` | `1d8bc7df88e2` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/qemu-10.0.3.huddef</code> (15 added, 69 removed)</summary>

```diff
--- pool/main/q/qemu/qemu-10.0.3.huddef
+++ sources/definitions/old/packages/qemu-10.0.3.huddef
@@ -1,6 +1,4 @@
-# HUD Package Definition - QEMU 10.0.3
-# Full virtualization solution for Linux on x86 hardware
-# Supports KVM hardware acceleration (Intel VT / AMD-V)
-# Reference: https://www.qemu.org/
+# HUD Package Definition - qemu 10.0.3
+# Auto-generated for oVirt infrastructure
 
 Package: qemu
@@ -8,79 +6,27 @@
 Architecture: x86_64
 Section: virtualization
-Depends: glib, pixman, alsa-lib, dtc, libslirp, sdl2
-Description: Full virtualization solution for Linux with KVM support
+Depends: gnutls,keyutils,libslirp,pipewire,cyrus-sasl,alsa-lib,curl,sphinx_rtd_theme,glib2,sdl2,bridgeutils,libjpeg,xdisplay,libseccomp,libusb,elogind,gtk3,libpng,dtc,mesa,fuse3,linux-pam,vte,libssh2
+Description: qemu-10.0.3
 Source: https://download.qemu.org/qemu-10.0.3.tar.xz
+Service: qemu
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-# Install required Python modules for QEMU build
-pip3 install distlib --break-system-packages 2>/dev/null || pip3 install distlib
-
-# Download and apply required patch for pip-25.2+ compatibility
-wget -nc https://www.linuxfromscratch.org/patches/blfs/12.4/qemu-10.0.3-python_fixes-1.patch -O ../qemu-10.0.3-python_fixes-1.patch 2>/dev/null || true
-patch -Np1 -i ../qemu-10.0.3-python_fixes-1.patch || true
-
-# Determine architecture
-if [ $(uname -m) = i686 ]; then
-   QEMU_ARCH=i386-softmmu
-else
-   QEMU_ARCH=x86_64-softmmu
-fi
-
-mkdir -vp build
-cd build
-../configure --prefix=/opt/hud              \
-             --sysconfdir=/etc              \
-             --localstatedir=/var           \
-             --target-list=$QEMU_ARCH       \
-             --audio-drv-list=alsa          \
-             --disable-pa                   \
-             --enable-slirp                 \
-             --enable-kvm                   \
-             --docdir=/opt/hud/share/doc/qemu-10.0.3
+../configure --prefix=/opt/hud --sysconfdir=/opt/hud/etc --enable-kvm --enable-virtfs --enable-vhost-net --target-list=x86_64-softmmu
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-cd build
 make -j$(nproc)
 
 [install]
-cd build
-make DESTDIR=$DESTDIR install
-install -vdm755 $DESTDIR/etc/qemu
+make install
 
 [postinst]
-ldconfig
+ldconfig 2>/dev/null || true
+echo "qemu 10.0.3 installed to /opt/hud"
 
-# Create kvm group if it doesn't exist
-getent group kvm >/dev/null || groupadd -r kvm
+[prerm]
+# Stop service if running
+systemctl stop hud-qemu 2>/dev/null || true
+systemctl disable hud-qemu 2>/dev/null || true
 
-# Set permissions on bridge helper
-chgrp kvm /opt/hud/libexec/qemu-bridge-helper 2>/dev/null || true
-chmod 4750 /opt/hud/libexec/qemu-bridge-helper 2>/dev/null || true
-
-# Create symlink for qemu command
-ln -sfv qemu-system-$(uname -m) /opt/hud/bin/qemu
-
-# Create symlinks in /usr/bin for libvirt compatibility
-ln -sf /opt/hud/bin/qemu-system-x86_64 /usr/bin/qemu-system-x86_64 2>/dev/null || true
-ln -sf /opt/hud/bin/qemu-img /usr/bin/qemu-img 2>/dev/null || true
-ln -sf /opt/hud/bin/qemu-nbd /usr/bin/qemu-nbd 2>/dev/null || true
-
-# Setup QEMU configuration
-install -vdm755 /etc/qemu
-cat > /etc/qemu/bridge.conf << 'EOF'
-allow br0
-allow virbr0
-EOF
-
-echo "QEMU 10.0.3 installed"
-echo "Binary: /opt/hud/bin/qemu-system-x86_64"
-echo "Add users to 'kvm' group for hardware acceleration: usermod -aG kvm <username>"
-echo "Test: qemu-system-x86_64 --version"
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/qemu-huddef/qemu-10.0.3.huddef</code> (5 added, 24 removed)</summary>

```diff
--- pool/main/q/qemu/qemu-10.0.3.huddef
+++ sources/definitions/qemu-huddef/qemu-10.0.3.huddef
@@ -2,5 +2,4 @@
 # Full virtualization solution for Linux on x86 hardware
 # Supports KVM hardware acceleration (Intel VT / AMD-V)
-# Reference: https://www.qemu.org/
 
 Package: qemu
@@ -35,4 +34,5 @@
 mkdir -vp build
 cd build
+
 ../configure --prefix=/opt/hud              \
              --sysconfdir=/etc              \
@@ -57,30 +57,11 @@
 
 [postinst]
-ldconfig
-
-# Create kvm group if it doesn't exist
 getent group kvm >/dev/null || groupadd -r kvm
-
-# Set permissions on bridge helper
 chgrp kvm /opt/hud/libexec/qemu-bridge-helper 2>/dev/null || true
 chmod 4750 /opt/hud/libexec/qemu-bridge-helper 2>/dev/null || true
-
-# Create symlink for qemu command
 ln -sfv qemu-system-$(uname -m) /opt/hud/bin/qemu
-
-# Create symlinks in /usr/bin for libvirt compatibility
-ln -sf /opt/hud/bin/qemu-system-x86_64 /usr/bin/qemu-system-x86_64 2>/dev/null || true
-ln -sf /opt/hud/bin/qemu-img /usr/bin/qemu-img 2>/dev/null || true
-ln -sf /opt/hud/bin/qemu-nbd /usr/bin/qemu-nbd 2>/dev/null || true
-
-# Setup QEMU configuration
 install -vdm755 /etc/qemu
-cat > /etc/qemu/bridge.conf << 'EOF'
-allow br0
-allow virbr0
-EOF
-
-echo "QEMU 10.0.3 installed"
-echo "Binary: /opt/hud/bin/qemu-system-x86_64"
-echo "Add users to 'kvm' group for hardware acceleration: usermod -aG kvm <username>"
-echo "Test: qemu-system-x86_64 --version"
+echo "allow br0" > /etc/qemu/bridge.conf 2>/dev/null || true
+ldconfig
+echo "✓ QEMU 10.0.3 installed to /opt/hud"
+echo "NOTE: Add users to 'kvm' group: usermod -a -G kvm <username>"
```

</details>


### `sdl2`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/s/sdl2/sdl2-2.32.8.huddef` | 2.32.8 | `44fc2abfcbeb` | `814663b9ba43` | **POOL** |
| `sources/definitions/old/packages/sdl2-2.32.8.huddef` | 2.32.8 | `35f09f1f1351` | `9d99666e2400` | alt |
| `sources/definitions/old/updated-packages/sdl2-2.32.8.huddef` | 2.32.8 | `35f09f1f1351` | `9d99666e2400` | alt |
| `sources/definitions/qemu-huddef/sdl2-2.32.8.huddef` | 2.32.8 | `44fc2abfcbeb` | `814663b9ba43` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/sdl2-2.32.8.huddef</code> (20 added, 21 removed)</summary>

```diff
--- pool/main/s/sdl2/sdl2-2.32.8.huddef
+++ sources/definitions/old/packages/sdl2-2.32.8.huddef
@@ -1,30 +1,29 @@
-# HUD Package Definition - SDL2 2.32.8
-# Simple DirectMedia Layer (recommended for QEMU)
-# Provides graphical display support for QEMU
+# HUD Package Definition - sdl2 2.32.8
+# Auto-generated for oVirt infrastructure
+
 Package: sdl2
 Version: 2.32.8
 Architecture: x86_64
-Section: graphics
-Depends: alsa-lib, libpulse, libx11, libxext, libxrandr, libxcursor, libxi, libxfixes, libxkbcommon, wayland
-Description: Cross-platform multimedia library for low-level access to audio, keyboard, mouse, and graphics
+Section: misc
+Depends: alsa-lib,libunwind,doxygen,wayland-protocols,x-window-system,ibus,libxkbcommon,xorg7-lib,pipewire
+Description: SDL2-2.32.8
 Source: https://www.libsdl.org/release/SDL2-2.32.8.tar.gz
+
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-./configure --prefix=/opt/hud \
-            --enable-video-wayland \
-            --enable-video-x11 \
-            --enable-alsa \
-            --enable-pulseaudio
+./configure --prefix=/opt/hud
+
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make -j$(nproc)
+
 [install]
-make DESTDIR=$DESTDIR install
+make install
+
 [postinst]
-ldconfig
-echo "✓ SDL2 2.32.8 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "sdl2 2.32.8 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `slang`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/s/slang/slang-2.3.3.huddef` | 2.3.3 | `08f95b8ac890` | `c3a190924ce6` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/slang-2.3.3.huddef` | 2.3.3 | `08f95b8ac890` | `c3a190924ce6` | **= POOL** |
| `sources/definitions/old/packages/slang-2.3.3.huddef` | 2.3.3 | `b7706d595dfa` | `aacb0683efdd` | alt |
| `sources/definitions/old/updated-packages/slang-2.3.3.huddef` | 2.3.3 | `b7706d595dfa` | `aacb0683efdd` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/slang-2.3.3.huddef</code> (13 added, 27 removed)</summary>

```diff
--- pool/main/s/slang/slang-2.3.3.huddef
+++ sources/definitions/old/packages/slang-2.3.3.huddef
@@ -1,5 +1,4 @@
-# HUD Package Definition - S-Lang 2.3.3
-# Interpreted language and display library
-# Required by newt for text-mode interfaces
+# HUD Package Definition - slang 2.3.3
+# S-Lang library for terminal handling
 
 Package: slang
@@ -7,35 +6,22 @@
 Architecture: x86_64
 Section: libraries
-Depends: glibc, readline, libpng
-Description: S-Lang interpreter and display library for text-mode UIs
+Depends: ncurses
+Description: S-Lang library for terminal handling
 Source: https://www.jedsoft.org/releases/slang/slang-2.3.3.tar.bz2
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-./configure --prefix=/opt/hud \
-            --sysconfdir=/etc \
-            --with-readline=gnu
+./configure \
+    --prefix=/opt/hud \
+    --with-readline=gnu \
+    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
+    CPPFLAGS="-I/opt/hud/include"
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-# Note: This package does not support parallel build
-make -j1 RPATH=
-
-[check]
-LC_ALL=C make check
+make -j1
 
 [install]
-make install_doc_dir=/opt/hud/share/doc/slang-2.3.3 \
-     SLSH_DOC_DIR=/opt/hud/share/doc/slang-2.3.3/slsh \
-     RPATH= \
-     DESTDIR=$DESTDIR install
+make DESTDIR=$DESTDIR install-all
 
 [postinst]
-ldconfig
-echo "✓ S-Lang 2.3.3 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "✓ slang 2.3.3 installed to /opt/hud"
```

</details>


### `sudo`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/s/sudo/sudo-1.9.16p2.huddef` | 1.9.16p2 | `18662dd27fe3` | `2ae17bd3af14` | **POOL** |
| `pool/main/s/sudo/sudo-1.9.17p2.huddef` | 1.9.17p2 | `77113988b530` | `06d595b849e1` | **POOL** |
| `sources/definitions/old/packages/sudo-1.9.17p2.huddef` | 1.9.17p2 | `70ea1c0173b2` | `98ffa7b5f30a` | alt |
| `sources/definitions/old/sudo-1.9.16p2.huddef` | 1.9.16p2 | `18662dd27fe3` | `2ae17bd3af14` | **= POOL** |
| `sources/definitions/old/sudo-1.9.17p2.huddef` | 1.9.17p2 | `77113988b530` | `06d595b849e1` | alt |
| `sources/definitions/old/updated-packages/sudo-1.9.16p2.huddef` | 1.9.16p2 | `18662dd27fe3` | `2ae17bd3af14` | **= POOL** |
| `sources/definitions/old/updated-packages/sudo-1.9.17p2.huddef` | 1.9.17p2 | `77113988b530` | `06d595b849e1` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/sudo-1.9.17p2.huddef</code> (13 added, 25 removed)</summary>

```diff
--- pool/main/s/sudo/sudo-1.9.16p2.huddef
+++ sources/definitions/old/packages/sudo-1.9.17p2.huddef
@@ -1,26 +1,15 @@
-
-# HUD Package Definition - sudo 1.9.16p2
+# HUD Package Definition - sudo 1.9.17p2
+# Auto-generated for oVirt infrastructure
 
 Package: sudo
-Version: 1.9.16p2
+Version: 1.9.17p2
 Architecture: x86_64
 Section: security
-Depends:
-Description: Execute commands as another user
-Source: https://www.sudo.ws/dist/sudo-1.9.16p2.tar.gz
+Depends: 
+Description: Sudo-1.9.17p2
+Source: https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz
 
 [configure]
-./configure \
- --prefix=/opt/hud \
- --libexecdir=/opt/hud/lib \
- --sysconfdir=/opt/hud/etc \
- --with-secure-path="/opt/hud/bin:/opt/hud/sbin:/usr/sbin:/usr/bin:/sbin:/bin" \
- --with-env-editor \
- --docdir=/opt/hud/share/doc/sudo-1.9.16p2 \
- --with-passprompt="[sudo] password for %p: " \
- --with-rundir=/opt/hud/var/run/sudo \
- --with-vardir=/opt/hud/var/lib/sudo \
- --with-logpath=/opt/hud/var/log/sudo.log \
- --without-pam
+./configure --prefix=/opt/hud --libexecdir=/opt/hud/lib --sysconfdir=/opt/hud/etc --with-secure-path="/opt/hud/bin:/opt/hud/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
 
 [build]
@@ -28,14 +17,13 @@
 
 [install]
-make DESTDIR=$DESTDIR install
+make install
 
 [postinst]
-mkdir -p /opt/hud/etc/sudoers.d
-chmod 750 /opt/hud/etc/sudoers.d
-chmod 440 /opt/hud/etc/sudoers 2>/dev/null || true
-chmod 4755 /opt/hud/bin/sudo 2>/dev/null || true
-echo "sudo installed to /opt/hud/bin/sudo"
+ldconfig 2>/dev/null || true
+echo "sudo 1.9.17p2 installed to /opt/hud"
 
 [prerm]
-# nothing to do before removal
+# Stop service if running
 
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>

<details><summary>diff → <code>sources/definitions/old/sudo-1.9.17p2.huddef</code> (15 added, 19 removed)</summary>

```diff
--- pool/main/s/sudo/sudo-1.9.16p2.huddef
+++ sources/definitions/old/sudo-1.9.17p2.huddef
@@ -1,26 +1,26 @@
-
-# HUD Package Definition - sudo 1.9.16p2
+# HUD Package Definition - sudo 1.9.17p2
+# Execute commands as another user
 
 Package: sudo
-Version: 1.9.16p2
+Version: 1.9.17p2
 Architecture: x86_64
 Section: security
 Depends:
 Description: Execute commands as another user
-Source: https://www.sudo.ws/dist/sudo-1.9.16p2.tar.gz
+Source: https://www.sudo.ws/dist/sudo-1.9.17p2.tar.gz
 
 [configure]
 ./configure \
- --prefix=/opt/hud \
- --libexecdir=/opt/hud/lib \
- --sysconfdir=/opt/hud/etc \
- --with-secure-path="/opt/hud/bin:/opt/hud/sbin:/usr/sbin:/usr/bin:/sbin:/bin" \
- --with-env-editor \
- --docdir=/opt/hud/share/doc/sudo-1.9.16p2 \
- --with-passprompt="[sudo] password for %p: " \
- --with-rundir=/opt/hud/var/run/sudo \
- --with-vardir=/opt/hud/var/lib/sudo \
- --with-logpath=/opt/hud/var/log/sudo.log \
- --without-pam
+    --prefix=/opt/hud \
+    --libexecdir=/opt/hud/lib \
+    --sysconfdir=/opt/hud/etc \
+    --with-secure-path="/opt/hud/bin:/opt/hud/sbin:/usr/sbin:/usr/bin:/sbin:/bin" \
+    --with-env-editor \
+    --docdir=/opt/hud/share/doc/sudo-1.9.17p2 \
+    --with-passprompt="[sudo] password for %p: " \
+    --with-rundir=/opt/hud/var/run/sudo \
+    --with-vardir=/opt/hud/var/lib/sudo \
+    --with-logpath=/opt/hud/var/log/sudo.log \
+    --without-pam
 
 [build]
@@ -36,6 +36,2 @@
 chmod 4755 /opt/hud/bin/sudo 2>/dev/null || true
 echo "sudo installed to /opt/hud/bin/sudo"
-
-[prerm]
-# nothing to do before removal
-
```

</details>


### `systemd`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/s/systemd/systemd-257.8.huddef` | 257.8 | `01d8aa660f6d` | `cb1ec503cce6` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/systemd-257.8.huddef` | 257.8 | `01d8aa660f6d` | `cb1ec503cce6` | **= POOL** |
| `sources/definitions/old/1 Feb 2026/systemd-257.8.huddef` | 257.8 | `01d8aa660f6d` | `cb1ec503cce6` | **= POOL** |
| `sources/definitions/old/updated-packages/systemd-257.8.huddef` | 257.8 | `177c4f148727` | `3c4cdbaee3c4` | alt |

<details><summary>diff → <code>sources/definitions/old/updated-packages/systemd-257.8.huddef</code> (10 added, 78 removed)</summary>

```diff
--- pool/main/s/systemd/systemd-257.8.huddef
+++ sources/definitions/old/updated-packages/systemd-257.8.huddef
@@ -1,93 +1,25 @@
-# HUD Package Definition - Systemd 257.8
+# HUD Package Definition - systemd 257.8
 # System and Service Manager
-# Controls startup, running, and shutdown of the system
-# Fixed: Added jinja2 Python module dependency check
 
 Package: systemd
 Version: 257.8
 Architecture: x86_64
-Section: system
-Depends: dbus, libcap, libgcrypt, util-linux, kmod, acl, xz, zstd
-Description: System and service manager for Linux, including udev device manager and logind
+Section: core
+Depends: meson, ninja, gperf, libcap, libseccomp, dbus, acl, libgcrypt, kmod
+Description: System and Service Manager
 Source: https://github.com/systemd/systemd/archive/v257.8/systemd-257.8.tar.gz
 
 [configure]
-# Ensure jinja2 Python module is installed (required for build)
-python3 -c "import jinja2" 2>/dev/null || pip3 install jinja2 --break-system-packages
-
-# Remove unneeded groups from udev rules
-sed -e 's/GROUP="render"/GROUP="video"/' \
-    -e 's/GROUP="sgx", //'               \
-    -i rules.d/50-udev-default.rules.in
-
-mkdir -p build
-cd build
-
-# Set up environment for finding libraries in /opt/hud
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LIBRARY_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include ${CFLAGS}"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64 ${LDFLAGS}"
-
-# Check if PAM is available
-PAM_OPT="disabled"
-if pkg-config --exists pam 2>/dev/null; then
-    PAM_OPT="enabled"
-elif [ -f /opt/hud/lib/libpam.so ] || [ -f /usr/lib/libpam.so ]; then
-    PAM_OPT="enabled"
-fi
-
-meson setup ..                    \
-    --prefix=/opt/hud             \
-    --buildtype=release           \
-    --pkg-config-path=/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig \
-    -D default-dnssec=no          \
-    -D firstboot=false            \
-    -D install-tests=false        \
-    -D ldconfig=false             \
-    -D sysusers=false             \
-    -D rpmmacrosdir=no            \
-    -D homed=disabled             \
-    -D userdb=false               \
-    -D man=disabled               \
-    -D mode=release               \
-    -D pam=${PAM_OPT}             \
-    -D dev-kvm-mode=0660          \
-    -D nobody-group=nogroup       \
-    -D sysupdate=disabled         \
-    -D ukify=disabled             \
-    -D selinux=disabled           \
-    -D apparmor=disabled          \
-    -D audit=disabled             \
-    -D polkit=disabled            \
-    -D bpf-framework=disabled     \
-    -D docdir=/opt/hud/share/doc/systemd-257.8
+meson setup build --prefix=/opt/hud --sysconfdir=/opt/hud/etc --localstatedir=/opt/hud/var \
+    -Drootprefix=/opt/hud -Drootlibdir=/opt/hud/lib -Dmode=release \
+    -Dpam=true -Dselinux=false -Dapparmor=false -Daudit=false
 
 [build]
-cd build
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-ninja
+ninja -C build
 
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+DESTDIR=$DESTDIR ninja -C build install
 
 [postinst]
-# Create machine-id if it doesn't exist
-if [ ! -f /etc/machine-id ]; then
-    /opt/hud/bin/systemd-machine-id-setup 2>/dev/null || true
-fi
-
-# Set up basic target structure
-/opt/hud/bin/systemctl preset-all 2>/dev/null || true
-
-# Create necessary runtime directories
-mkdir -p /run/systemd/seats
-mkdir -p /run/systemd/sessions
-mkdir -p /run/systemd/users
-
 ldconfig 2>/dev/null || true
-echo "✓ Systemd 257.8 installed to /opt/hud"
-echo "  Note: Download man pages separately from:"
-echo "  https://anduin.linuxfromscratch.org/LFS/systemd-man-pages-257.8.tar.xz"
+echo "✓ systemd 257.8 installed to /opt/hud"
```

</details>


### `tree`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/t/tree/tree-2.2.1.huddef` | 2.2.1 | `1e86de24b0ee` | `872565497892` | **POOL** |
| `sources/definitions/old/packages/tree-2.2.1.huddef` | 2.2.1 | `b3bed259b8fe` | `5fdca5c8824e` | alt |
| `sources/definitions/old/tree-2.2.1.huddef` | 2.2.1 | `1e86de24b0ee` | `872565497892` | **= POOL** |
| `sources/definitions/old/updated-packages/tree-2.2.1.huddef` | 2.2.1 | `1e86de24b0ee` | `872565497892` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/tree-2.2.1.huddef</code> (0 added, 1 removed)</summary>

```diff
--- pool/main/t/tree/tree-2.2.1.huddef
+++ sources/definitions/old/packages/tree-2.2.1.huddef
@@ -27,3 +27,2 @@
     echo "⚠ Warning: /opt/hud/bin/tree not found"
 fi
-
```

</details>


### `util-macros`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/u/util-macros/util-macros-1.20.2.huddef` | 1.20.2 | `14dc1899c014` | `c4b43f94c579` | **POOL** |
| `sources/definitions/old/0/util-macros-1.20.2.huddef` | 1.20.2 | `14dc1899c014` | `c4b43f94c579` | **= POOL** |
| `sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/util-macros-1.20.2.huddef` | 1.20.2 | `479c6e0d0dfc` | `4efc8bfcfc58` | alt |
| `sources/definitions/old/updated-packages/util-macros-1.20.2.huddef` | 1.20.2 | `14dc1899c014` | `c4b43f94c579` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/util-macros-1.20.2.huddef</code> (11 added, 4 removed)</summary>

```diff
--- pool/main/u/util-macros/util-macros-1.20.2.huddef
+++ sources/definitions/old/1 Feb 2026/java-openjdk-huddef/java-huddef-packages/util-macros-1.20.2.huddef
@@ -1,4 +1,6 @@
 # HUD Package Definition - util-macros 1.20.2
-# M4 macros used by Xorg packages
+# X.Org Utility Macros
+# M4 macros used by all X.Org configure scripts
+
 Package: util-macros
 Version: 1.20.2
@@ -6,12 +8,17 @@
 Section: xorg
 Depends:
-Description: M4 macros used by all of the Xorg packages
+Description: X.Org M4 macros used by all configure scripts
 Source: https://www.x.org/pub/individual/util/util-macros-1.20.2.tar.xz
+
 [configure]
-./configure --prefix=/opt/hud --sysconfdir=/etc --localstatedir=/var --disable-static
+./configure --prefix=/opt/hud
+
 [build]
-echo "No build step required"
+make -j$(nproc)
+
 [install]
 make DESTDIR=$DESTDIR install
+
 [postinst]
 echo "✓ util-macros 1.20.2 installed to /opt/hud"
+echo "  Provides: xorg-macros.pc for pkg-config"
```

</details>


### `vala`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/v/vala/vala-0.56.18.huddef` | 0.56.18 | `5ad11fc0cb22` | `97fb9d11795c` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/vala-0.56.18.huddef` | 0.56.18 | `5ad11fc0cb22` | `97fb9d11795c` | **= POOL** |
| `sources/definitions/old/packages/vala-0.56.18.huddef` | 0.56.18 | `5fee164ce122` | `2bf55a43bf10` | alt |
| `sources/definitions/old/updated-packages/vala-0.56.18.huddef` | 0.56.18 | `5fee164ce122` | `2bf55a43bf10` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/vala-0.56.18.huddef</code> (15 added, 46 removed)</summary>

```diff
--- pool/main/v/vala/vala-0.56.18.huddef
+++ sources/definitions/old/packages/vala-0.56.18.huddef
@@ -1,60 +1,29 @@
-# HUD Package Definition - Vala 0.56.18
-# Programming language for GNOME
-# Recommended by NetworkManager
+# HUD Package Definition - vala 0.56.18
+# Auto-generated for oVirt infrastructure
 
 Package: vala
 Version: 0.56.18
 Architecture: x86_64
-Section: development
-Depends: glib
-Description: Compiler for the Vala programming language
+Section: misc
+Depends: libxslt,glib2,graphviz,dbus
+Description: Vala-0.56.18
 Source: https://download.gnome.org/sources/vala/0.56/vala-0.56.18.tar.xz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:/usr/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-# Check if both gobject-introspection AND graphviz (libgvc) are available
-# valadoc requires both g-i and graphviz
-GI_AVAILABLE=0
-GVC_AVAILABLE=0
-
-if pkg-config --exists gobject-introspection-1.0 2>/dev/null; then
-    GI_AVAILABLE=1
-    echo "gobject-introspection: found"
-else
-    echo "gobject-introspection: NOT found"
-fi
-
-if pkg-config --exists libgvc 2>/dev/null; then
-    GVC_AVAILABLE=1
-    echo "libgvc (Graphviz): found"
-else
-    echo "libgvc (Graphviz): NOT found"
-fi
-
-if [ "$GI_AVAILABLE" = "1" ] && [ "$GVC_AVAILABLE" = "1" ]; then
-    echo "Building with full valadoc support"
-    ./configure --prefix=/opt/hud
-else
-    echo "Building without valadoc (missing dependencies)"
-    ./configure --prefix=/opt/hud --disable-valadoc
-fi
+./configure --prefix=/opt/hud
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
 make -j$(nproc)
 
-[check]
-make check
-
 [install]
-make DESTDIR=$DESTDIR install
+make install
 
 [postinst]
-ldconfig
-echo "✓ Vala 0.56.18 installed to /opt/hud"
+ldconfig 2>/dev/null || true
+echo "vala 0.56.18 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `yajl`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/y/yajl/yajl-2.1.0.huddef` | 2.1.0 | `cace9435f234` | `23f7a96decf8` | **POOL** |
| `sources/definitions/old/0/yajl-2.1.0.huddef` | 2.1.0 | `11c6052a172a` | `cc628eaa33a3` | alt |
| `sources/definitions/old/packages/yajl-2.1.0.huddef` | 2.1.0 | `173400ca353e` | `3d7db37278a2` | alt |
| `sources/definitions/old/updated-packages/yajl-2.1.0.huddef` | 2.1.0 | `cace9435f234` | `23f7a96decf8` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/yajl-2.1.0.huddef</code> (9 added, 11 removed)</summary>

```diff
--- pool/main/y/yajl/yajl-2.1.0.huddef
+++ sources/definitions/old/0/yajl-2.1.0.huddef
@@ -1,5 +1,4 @@
 # HUD Package Definition - yajl 2.1.0
 # Yet Another JSON Library
-
 Package: yajl
 Version: 2.1.0
@@ -7,18 +6,17 @@
 Section: libraries
 Depends: cmake
-Description: Yet Another JSON Library - a fast streaming JSON parsing library in C
+Description: Yet Another JSON Library - fast streaming JSON parser
 Source: https://github.com/lloyd/yajl/archive/refs/tags/2.1.0.tar.gz
-
 [configure]
-sed -i 's/GET_TARGET_PROPERTY(\(.*\) \(.*\) LOCATION)/set(\1 $<TARGET_FILE:\2>)/' reformatter/CMakeLists.txt verify/CMakeLists.txt
-mkdir -p build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/opt/hud -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_POLICY_DEFAULT_CMP0026=OLD ..
-
+mkdir -p build
+cd build
+cmake -DCMAKE_INSTALL_PREFIX=/opt/hud -DCMAKE_BUILD_TYPE=Release ..
 [build]
-cd build && make -j$(nproc)
-
+cd build
+make
 [install]
-cd build && make DESTDIR=$DESTDIR install
-
+cd build
+make DESTDIR=$DESTDIR install
 [postinst]
-ldconfig 2>/dev/null || true
 echo "✓ yajl 2.1.0 installed to /opt/hud"
+/sbin/ldconfig
```

</details>

<details><summary>diff → <code>sources/definitions/old/packages/yajl-2.1.0.huddef</code> (12 added, 7 removed)</summary>

```diff
--- pool/main/y/yajl/yajl-2.1.0.huddef
+++ sources/definitions/old/packages/yajl-2.1.0.huddef
@@ -1,4 +1,4 @@
 # HUD Package Definition - yajl 2.1.0
-# Yet Another JSON Library
+# Auto-generated for oVirt infrastructure
 
 Package: yajl
@@ -7,18 +7,23 @@
 Section: libraries
 Depends: cmake
-Description: Yet Another JSON Library - a fast streaming JSON parsing library in C
+Description: Yet Another JSON Library
 Source: https://github.com/lloyd/yajl/archive/refs/tags/2.1.0.tar.gz
 
 [configure]
-sed -i 's/GET_TARGET_PROPERTY(\(.*\) \(.*\) LOCATION)/set(\1 $<TARGET_FILE:\2>)/' reformatter/CMakeLists.txt verify/CMakeLists.txt
-mkdir -p build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/opt/hud -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_POLICY_DEFAULT_CMP0026=OLD ..
+cmake -DCMAKE_INSTALL_PREFIX=/opt/hud .
 
 [build]
-cd build && make -j$(nproc)
+make
 
 [install]
-cd build && make DESTDIR=$DESTDIR install
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ yajl 2.1.0 installed to /opt/hud"
+echo "yajl 2.1.0 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `zlib`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/z/zlib/zlib-1.3.1.huddef` | 1.3.1 | `4d0e1cd24351` | `0c2a40d051d0` | **POOL** |
| `sources/definitions/old/packages/zlib-1.3.1.huddef` | 1.3.1 | `a86e270132c7` | `fdca4c05d99f` | alt |
| `sources/definitions/old/updated-packages/zlib-1.3.1.huddef` | 1.3.1 | `4d0e1cd24351` | `0c2a40d051d0` | **= POOL** |
| `sources/definitions/old/zlib-1.3.1.huddef` | 1.3.1 | `4d0e1cd24351` | `0c2a40d051d0` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/zlib-1.3.1.huddef</code> (0 added, 1 removed)</summary>

```diff
--- pool/main/z/zlib/zlib-1.3.1.huddef
+++ sources/definitions/old/packages/zlib-1.3.1.huddef
@@ -24,3 +24,2 @@
 ldconfig 2>/dev/null || true
 echo "✓ zlib 1.3.1 installed to /opt/hud"
-
```

</details>


## Differ only across versions — 22 packages

Content differs only between different `Version:` values. Normal history; keep the pool copy's version.


### `expat`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/e/expat/expat-2.6.4.huddef` | 2.6.4 | `653abe89c93b` | `68ff04afca1a` | **POOL** |
| `pool/main/e/expat/expat-2.7.1.huddef` | 2.7.1 | `be710bd30b5c` | `cc97363d3b73` | **POOL** |
| `sources/definitions/old/0/expat-2.7.1.huddef` | 2.7.1 | `be710bd30b5c` | `cc97363d3b73` | alt |
| `sources/definitions/old/expat-2.6.4.huddef` | 2.6.4 | `653abe89c93b` | `68ff04afca1a` | **= POOL** |
| `sources/definitions/old/packages/expat-2.6.4.huddef` | 2.6.4 | `653abe89c93b` | `68ff04afca1a` | **= POOL** |
| `sources/definitions/old/updated-packages/expat-2.6.4.huddef` | 2.6.4 | `653abe89c93b` | `68ff04afca1a` | **= POOL** |
| `sources/definitions/old/updated-packages/expat-2.7.1.huddef` | 2.7.1 | `be710bd30b5c` | `cc97363d3b73` | alt |

<details><summary>diff → <code>sources/definitions/old/0/expat-2.7.1.huddef</code> (9 added, 16 removed)</summary>

```diff
--- pool/main/e/expat/expat-2.6.4.huddef
+++ sources/definitions/old/0/expat-2.7.1.huddef
@@ -1,25 +1,18 @@
-# HUD Package Definition - expat 2.6.4
-# XML parser library
-
+# HUD Package Definition - expat 2.7.1
+# XML parsing C library
 Package: expat
-Version: 2.6.4
+Version: 2.7.1
 Architecture: x86_64
 Section: libraries
 Depends:
-Description: Stream-oriented XML parser library
-Source: https://github.com/libexpat/libexpat/releases/download/R_2_6_4/expat-2.6.4.tar.xz
-
+Description: Stream-oriented XML parsing C library
+Source: https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz
 [configure]
-./configure \
-    --prefix=/opt/hud \
-    --disable-static
-
+./configure --prefix=/opt/hud --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
-echo "✓ expat 2.6.4 installed to /opt/hud"
+echo "✓ expat 2.7.1 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `freetype`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/f/freetype/freetype-2.14.0.huddef` | 2.14.0 | `1e818d3c7bae` | `06e7fa2afa8d` | **POOL** |
| `sources/definitions/old/0/freetype-2.13.3.huddef` | 2.13.3 | `aaf004f1ae2d` | `e9babf75e6f3` | alt |
| `sources/definitions/old/updated-packages/freetype-2.14.0.huddef` | 2.14.0 | `1e818d3c7bae` | `06e7fa2afa8d` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/0/freetype-2.13.3.huddef</code> (13 added, 16 removed)</summary>

```diff
--- pool/main/f/freetype/freetype-2.14.0.huddef
+++ sources/definitions/old/0/freetype-2.13.3.huddef
@@ -1,23 +1,20 @@
-# HUD Package Definition - FreeType 2.14.0
-# Font rendering library
-
+# HUD Package Definition - freetype 2.13.3
+# Library for rendering TrueType fonts
 Package: freetype
-Version: 2.14.0
+Version: 2.13.3
 Architecture: x86_64
-Section: libraries
-Depends: zlib, bzip2, libpng
-Description: High-quality font rendering library
-Source: https://sourceforge.net/projects/freetype/files/freetype2/2.14.0/freetype-2.14.0.tar.xz
-
+Section: graphics
+Depends: libpng
+Description: Library which allows applications to properly render TrueType fonts
+Source: https://downloads.sourceforge.net/freetype/freetype-2.13.3.tar.xz
 [configure]
-./configure --prefix=/opt/hud --enable-freetype-config --disable-static --with-zlib=yes --with-bzip2=yes --with-png=yes
-
+sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
+sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
+./configure --prefix=/opt/hud --enable-freetype-config --disable-static
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
-echo "✓ FreeType 2.14.0 installed to /opt/hud"
+echo "✓ freetype 2.13.3 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `glib2`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/packages/glib2-2.84.0.huddef` | 2.84.0 | `baa3fd5fd29b` | `11beec6e64fb` | alt |
| `sources/definitions/old/packages/glib2-2.84.4.huddef` | 2.84.4 | `2639f6474926` | `7ef1f0f8fc02` | alt |
| `sources/definitions/old/updated-packages/glib2-2.84.4.huddef` | 2.84.4 | `2639f6474926` | `7ef1f0f8fc02` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/packages/glib2-2.84.0.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/glib2-2.84.4.huddef</code> (16 added, 21 removed)</summary>

```diff
--- sources/definitions/old/packages/glib2-2.84.0.huddef
+++ sources/definitions/old/packages/glib2-2.84.4.huddef
@@ -1,34 +1,29 @@
-# HUD Package Definition - glib2 2.84.0
-# Low-level core library for GNOME
+# HUD Package Definition - glib2 2.84.4
+# Auto-generated for oVirt infrastructure
 
 Package: glib2
-Version: 2.84.0
+Version: 2.84.4
 Architecture: x86_64
 Section: libraries
-Depends: pcre2,libffi,zlib,meson,ninja
-Description: Low-level core library that forms the basis of GTK+ and GNOME
-Source: https://download.gnome.org/sources/glib/2.84/glib-2.84.0.tar.xz
+Depends: fuse3,gdb,dbus,gi-docgen,shared-mime-info,docbook-xsl,docutils,mako,glib-networking,gtk-doc,cairo,pcre2,docbook,desktop-file-utils
+Description: GLib-2.84.4
+Source: https://download.gnome.org/sources/glib/2.84/glib-2.84.4.tar.xz
 
 [configure]
-mkdir -p build && cd build && meson setup .. \
-    --prefix=/opt/hud \
-    --buildtype=release \
-    -Dintrospection=disabled \
-    -Dman-pages=disabled \
-    -Ddtrace=false \
-    -Dsystemtap=false \
-    -Dinstalled_tests=false
+meson setup build --prefix=/opt/hud --buildtype=release
 
 [build]
-cd build && ninja -j$(nproc)
+ninja -C build
 
 [install]
-cd build && DESTDIR=$DESTDIR ninja install
+DESTDIR=$DESTDIR ninja -C build install
 
 [postinst]
 ldconfig 2>/dev/null || true
-# Compile GLib schemas if any exist
-if [ -d /opt/hud/share/glib-2.0/schemas ]; then
-    /opt/hud/bin/glib-compile-schemas /opt/hud/share/glib-2.0/schemas 2>/dev/null || true
-fi
-echo "✓ glib2 2.84.0 installed to /opt/hud"
+echo "glib2 2.84.4 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `gtk3`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/0/gtk3-3.24.48.huddef` | 3.24.48 | `2d090b915869` | `ace4ceaa4b3b` | alt |
| `sources/definitions/old/packages/gtk3-3.24.50.huddef` | 3.24.50 | `d050569bbf9a` | `0a776db8bd71` | alt |
| `sources/definitions/old/updated-packages/gtk3-3.24.50.huddef` | 3.24.50 | `d050569bbf9a` | `0a776db8bd71` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/0/gtk3-3.24.48.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/gtk3-3.24.50.huddef</code> (22 added, 22 removed)</summary>

```diff
--- sources/definitions/old/0/gtk3-3.24.48.huddef
+++ sources/definitions/old/packages/gtk3-3.24.50.huddef
@@ -1,29 +1,29 @@
-# HUD Package Definition - gtk3 3.24.48
-# GIMP Toolkit version 3
+# HUD Package Definition - gtk3 3.24.50
+# Auto-generated for oVirt infrastructure
+
 Package: gtk3
-Version: 3.24.48
+Version: 3.24.50
 Architecture: x86_64
 Section: graphics
-Depends: glib,pango,gdk-pixbuf,cairo,atk,at-spi2-core,libX11,libXi,libXrandr,libXcursor,libXfixes,libXinerama,libXcomposite,libXdamage,libepoxy,wayland,wayland-protocols,libxkbcommon,mesa
-Description: GIMP Toolkit version 3 for creating graphical user interfaces
-Source: https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.48.tar.xz
+Depends: oxygen-icons,adwaita-icon-theme,iso-codes,libepoxy,libxslt,pango,tinysparql,libxkbcommon,gtk-doc,libcloudproviders,wayland-protocols,glib2,dejavu-fonts,pyatspi2,colord,wayland,docbook-xsl,cups,at-spi2-core,gdk-pixbuf,sassc
+Description: GTK-3.24.50
+Source: https://download.gnome.org/sources/gtk/3.24/gtk-3.24.50.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release \
-    -Dman=false \
-    -Dbroadway_backend=true \
-    -Dx11_backend=true \
-    -Dwayland_backend=true \
-    ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ gtk3 3.24.48 installed to /opt/hud"
-/sbin/ldconfig
-gtk-query-immodules-3.0 --update-cache 2>/dev/null || true
-glib-compile-schemas /opt/hud/share/glib-2.0/schemas 2>/dev/null || true
+ldconfig 2>/dev/null || true
+echo "gtk3 3.24.50 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `kmod`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/k/kmod/kmod-34.huddef` | 34 | `948db20716b1` | `a88b31d0061c` | **POOL** |
| `sources/definitions/old/updated-packages/kmod-34.2.huddef` | 34.2 | `fe6a6bb78f9d` | `bb167949c6c6` | alt |
| `sources/definitions/old/updated-packages/kmod-34.huddef` | 34 | `948db20716b1` | `a88b31d0061c` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/updated-packages/kmod-34.2.huddef</code> (4 added, 4 removed)</summary>

```diff
--- pool/main/k/kmod/kmod-34.huddef
+++ sources/definitions/old/updated-packages/kmod-34.2.huddef
@@ -1,11 +1,11 @@
-# HUD Package Definition - kmod 34
+# HUD Package Definition - kmod 34.2
 # Linux kernel module tools
 
 Package: kmod
-Version: 34
+Version: 34.2
 Architecture: x86_64
 Section: core
 Description: Libraries and utilities for loading kernel modules
-Source: https://kernel.org/pub/linux/utils/kernel/kmod/kmod-34.tar.xz
+Source: https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-34.2.tar.xz
 
 [configure]
@@ -20,3 +20,3 @@
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ kmod 34 installed to /opt/hud"
+echo "✓ kmod 34.2 installed to /opt/hud"
```

</details>


### `libdrm`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libdrm/libdrm-2.4.124.huddef` | 2.4.124 | `71ea3e46a398` | `827c81530de8` | **POOL** |
| `sources/definitions/old/0/libdrm-2.4.124.huddef` | 2.4.124 | `71ea3e46a398` | `827c81530de8` | **= POOL** |
| `sources/definitions/old/packages/libdrm-2.4.125.huddef` | 2.4.125 | `5d27e2eeb0bd` | `f88d579276e4` | alt |
| `sources/definitions/old/updated-packages/libdrm-2.4.124.huddef` | 2.4.124 | `71ea3e46a398` | `827c81530de8` | **= POOL** |
| `sources/definitions/old/updated-packages/libdrm-2.4.125.huddef` | 2.4.125 | `5d27e2eeb0bd` | `f88d579276e4` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/libdrm-2.4.125.huddef</code> (23 added, 16 removed)</summary>

```diff
--- pool/main/l/libdrm/libdrm-2.4.124.huddef
+++ sources/definitions/old/packages/libdrm-2.4.125.huddef
@@ -1,22 +1,29 @@
-# HUD Package Definition - libdrm 2.4.124
-# Direct Rendering Manager library
+# HUD Package Definition - libdrm 2.4.125
+# Auto-generated for oVirt infrastructure
+
 Package: libdrm
-Version: 2.4.124
+Version: 2.4.125
 Architecture: x86_64
-Section: graphics
-Depends: libpciaccess,meson,ninja
-Description: Direct Rendering Manager runtime library
-Source: https://dri.freedesktop.org/libdrm/libdrm-2.4.124.tar.xz
+Section: libraries
+Depends: libatomic_ops,valgrind,libxslt,cmake,docutils,xorg7-lib,cairo,docbook
+Description: Libdrm-2.4.125
+Source: https://dri.freedesktop.org/libdrm/libdrm-2.4.125.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release -Dudev=true -Dvalgrind=disabled ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ libdrm 2.4.124 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "libdrm 2.4.125 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `libffi`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libffi/libffi-3.4.6.huddef` | 3.4.6 | `1dd030e0748a` | `77b12a00a00d` | **POOL** |
| `pool/main/l/libffi/libffi-3.4.8.huddef` | 3.4.8 | `5b0c5971e20b` | `897e3e695ec3` | **POOL** |
| `sources/definitions/old/0/libffi-3.4.8.huddef` | 3.4.8 | `5b0c5971e20b` | `897e3e695ec3` | alt |
| `sources/definitions/old/packages/libffi-3.4.6.huddef` | 3.4.6 | `1dd030e0748a` | `77b12a00a00d` | **= POOL** |
| `sources/definitions/old/updated-packages/libffi-3.4.6.huddef` | 3.4.6 | `1dd030e0748a` | `77b12a00a00d` | **= POOL** |
| `sources/definitions/old/updated-packages/libffi-3.4.8.huddef` | 3.4.8 | `5b0c5971e20b` | `897e3e695ec3` | alt |

<details><summary>diff → <code>sources/definitions/old/0/libffi-3.4.8.huddef</code> (7 added, 16 removed)</summary>

```diff
--- pool/main/l/libffi/libffi-3.4.6.huddef
+++ sources/definitions/old/0/libffi-3.4.8.huddef
@@ -1,27 +1,18 @@
-# HUD Package Definition - libffi 3.4.6
+# HUD Package Definition - libffi 3.4.8
 # Foreign Function Interface library
-
 Package: libffi
-Version: 3.4.6
+Version: 3.4.8
 Architecture: x86_64
 Section: libraries
 Depends:
 Description: Portable foreign function interface library
-Source: https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz
-
+Source: https://github.com/libffi/libffi/releases/download/v3.4.8/libffi-3.4.8.tar.gz
 [configure]
-./configure \
-    --prefix=/opt/hud \
-    --disable-static \
-    --with-gcc-arch=native \
-    --disable-exec-static-tramp
-
+./configure --prefix=/opt/hud --disable-static --with-gcc-arch=native
 [build]
-make -j$(nproc)
-
+make
 [install]
 make DESTDIR=$DESTDIR install
-
 [postinst]
-ldconfig 2>/dev/null || true
-echo "✓ libffi 3.4.6 installed to /opt/hud"
+echo "✓ libffi 3.4.8 installed to /opt/hud"
+/sbin/ldconfig
```

</details>


### `libgcrypt`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libgcrypt/libgcrypt-1.11.1.huddef` | 1.11.1 | `757c854f214d` | `1426470f87ea` | **POOL** |
| `pool/main/l/libgcrypt/libgcrypt-1.11.2.huddef` | 1.11.2 | `355bc172dc55` | `21b43abfdbe1` | **POOL** |
| `sources/definitions/old/1 Feb 2026/libgcrypt-1.11.2.huddef` | 1.11.2 | `355bc172dc55` | `21b43abfdbe1` | alt |
| `sources/definitions/old/updated-packages/libgcrypt-1.11.1.huddef` | 1.11.1 | `757c854f214d` | `1426470f87ea` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/libgcrypt-1.11.2.huddef</code> (16 added, 7 removed)</summary>

```diff
--- pool/main/l/libgcrypt/libgcrypt-1.11.1.huddef
+++ sources/definitions/old/1 Feb 2026/libgcrypt-1.11.2.huddef
@@ -1,23 +1,32 @@
-# HUD Package Definition - libgcrypt 1.11.1
-# Cryptographic library
+# HUD Package Definition - libgcrypt 1.11.2
+# General Purpose Crypto Library
+# High level interface to cryptographic building blocks
 
 Package: libgcrypt
-Version: 1.11.1
+Version: 1.11.2
 Architecture: x86_64
 Section: security
 Depends: libgpg-error
-Description: General purpose cryptographic library
-Source: https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.1.tar.bz2
+Description: General purpose crypto library based on GnuPG code with extendable API
+Source: https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.11.2.tar.bz2
 
 [configure]
-./configure --prefix=/opt/hud --disable-static --with-libgpg-error-prefix=/opt/hud
+./configure --prefix=/opt/hud
 
 [build]
 make -j$(nproc)
 
+# Build documentation (optional, requires texinfo)
+make -C doc html 2>/dev/null || true
+
 [install]
 make DESTDIR=$DESTDIR install
 
+# Install documentation
+install -v -dm755 $DESTDIR/opt/hud/share/doc/libgcrypt-1.11.2
+install -v -m644 README doc/README.apichanges \
+    $DESTDIR/opt/hud/share/doc/libgcrypt-1.11.2/ 2>/dev/null || true
+
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libgcrypt 1.11.1 installed to /opt/hud"
+echo "✓ libgcrypt 1.11.2 installed to /opt/hud"
```

</details>


### `libgpg-error`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/l/libgpg-error/libgpg-error-1.51.huddef` | 1.51 | `72278a0ee282` | `724fb02af3fc` | **POOL** |
| `pool/main/l/libgpg-error/libgpg-error-1.55.huddef` | 1.55 | `f872cd04cc36` | `4a11f0abcf95` | **POOL** |
| `sources/definitions/old/1 Feb 2026/libgpg-error-1.55.huddef` | 1.55 | `f872cd04cc36` | `4a11f0abcf95` | alt |
| `sources/definitions/old/updated-packages/libgpg-error-1.51.huddef` | 1.51 | `72278a0ee282` | `724fb02af3fc` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/1 Feb 2026/libgpg-error-1.55.huddef</code> (9 added, 7 removed)</summary>

```diff
--- pool/main/l/libgpg-error/libgpg-error-1.51.huddef
+++ sources/definitions/old/1 Feb 2026/libgpg-error-1.55.huddef
@@ -1,15 +1,16 @@
-# HUD Package Definition - libgpg-error 1.51
-# GnuPG error library
+# HUD Package Definition - libgpg-error 1.55
+# GnuPG Error Library
+# Common error values for all GnuPG components
 
 Package: libgpg-error
-Version: 1.51
+Version: 1.55
 Architecture: x86_64
 Section: security
 Depends:
-Description: Library for common error values and messages in GnuPG components
-Source: https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.51.tar.bz2
+Description: Library that defines common error values for all GnuPG components
+Source: https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.55.tar.bz2
 
 [configure]
-./configure --prefix=/opt/hud --disable-static
+./configure --prefix=/opt/hud
 
 [build]
@@ -18,6 +19,7 @@
 [install]
 make DESTDIR=$DESTDIR install
+install -v -m644 -D README $DESTDIR/opt/hud/share/doc/libgpg-error-1.55/README
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ libgpg-error 1.51 installed to /opt/hud"
+echo "✓ libgpg-error 1.55 installed to /opt/hud"
```

</details>


### `ncurses`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/ncurses/ncurses-6.5.20250809.huddef` | 6.5.20250809 | `55729ecafb5b` | `397c4416fc38` | **POOL** |
| `sources/definitions/old/packages/ncurses-6.5.huddef` | 6.5 | `e39c35edef22` | `bc46599cde51` | alt |
| `sources/definitions/old/updated-packages/ncurses-6.5.20250809.huddef` | 6.5.20250809 | `55729ecafb5b` | `397c4416fc38` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/ncurses-6.5.huddef</code> (14 added, 28 removed)</summary>

```diff
--- pool/main/n/ncurses/ncurses-6.5.20250809.huddef
+++ sources/definitions/old/packages/ncurses-6.5.huddef
@@ -1,28 +1,24 @@
-# HUD Package Definition - ncurses 6.5-20250809
-# Terminal handling library - Based on LFS 12.4-systemd
-# Updated version with GCC 15 compatibility
+# HUD Package Definition - ncurses 6.5
+# Terminal handling library
 
 Package: ncurses
-Version: 6.5.20250809
+Version: 6.5
 Architecture: x86_64
 Section: libraries
 Depends:
-Description: New curses library - terminal handling (LFS 12.4)
-Source: https://invisible-mirror.net/archives/ncurses/current/ncurses-6.5-20250809.tgz
+Description: New curses library - terminal handling
+Source: https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz
 
 [configure]
 ./configure \
     --prefix=/opt/hud \
-    --mandir=/opt/hud/share/man \
-    --with-manpage-format=normal \
     --with-shared \
-    --without-normal \
-    --with-cxx-shared \
     --without-debug \
     --without-ada \
+    --with-cxx-shared \
     --enable-widec \
     --enable-pc-files \
     --with-pkg-config-libdir=/opt/hud/lib/pkgconfig \
-    AWK=gawk
+    --enable-symlinks
 
 [build]
@@ -31,29 +27,19 @@
 [install]
 make DESTDIR=$DESTDIR install
-
-# Create libncurses.so symlink (needed by some packages)
-ln -sfv libncursesw.so $DESTDIR/opt/hud/lib/libncurses.so
-
-# Fix curses.h to always use wide-character data structures
-sed -e 's/^#if.*XOPEN.*$/#if 1/' \
-    -i $DESTDIR/opt/hud/include/curses.h
-
-# Create non-wide character compatibility symlinks
+# Create non-wide character symlinks for compatibility
 for lib in ncurses form panel menu; do
     rm -f $DESTDIR/opt/hud/lib/lib${lib}.so
     echo "INPUT(-l${lib}w)" > $DESTDIR/opt/hud/lib/lib${lib}.so
-    ln -sfv lib${lib}w.a $DESTDIR/opt/hud/lib/lib${lib}.a 2>/dev/null || true
+    ln -sf lib${lib}w.a $DESTDIR/opt/hud/lib/lib${lib}.a 2>/dev/null || true
 done
-
-# Create include directory symlink
-ln -sfv ncursesw $DESTDIR/opt/hud/include/ncurses 2>/dev/null || true
-
-# Create pkg-config symlinks for non-wide versions
+# Create ncurses -> ncursesw symlinks for headers
+ln -sf ncursesw $DESTDIR/opt/hud/include/ncurses 2>/dev/null || true
+# Create pkg-config files for non-wide versions
 for pc in ncurses form panel menu; do
     [ -f $DESTDIR/opt/hud/lib/pkgconfig/${pc}w.pc ] && \
-    ln -sfv ${pc}w.pc $DESTDIR/opt/hud/lib/pkgconfig/${pc}.pc 2>/dev/null || true
+    ln -sf ${pc}w.pc $DESTDIR/opt/hud/lib/pkgconfig/${pc}.pc 2>/dev/null || true
 done
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ ncurses 6.5-20250809 installed to /opt/hud"
+echo "✓ ncurses 6.5 installed to /opt/hud"
```

</details>


### `nghttp2`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/n/nghttp2/nghttp2-1.66.0.huddef` | 1.66.0 | `aaffdaa00caa` | `625bd15da1c2` | **POOL** |
| `sources/definitions/old/packages/nghttp2-1.64.0.huddef` | 1.64.0 | `02a9337ab943` | `a963ae4ec088` | alt |
| `sources/definitions/old/packages/nghttp2-1.66.0.huddef` | 1.66.0 | `aaffdaa00caa` | `625bd15da1c2` | **= POOL** |
| `sources/definitions/old/updated-packages/nghttp2-1.66.0.huddef` | 1.66.0 | `aaffdaa00caa` | `625bd15da1c2` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/nghttp2-1.64.0.huddef</code> (16 added, 16 removed)</summary>

```diff
--- pool/main/n/nghttp2/nghttp2-1.66.0.huddef
+++ sources/definitions/old/packages/nghttp2-1.64.0.huddef
@@ -1,15 +1,21 @@
-# HUD Package Definition - nghttp2 1.66.0
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - nghttp2 1.64.0
+# HTTP/2 C Library
 
 Package: nghttp2
-Version: 1.66.0
+Version: 1.64.0
 Architecture: x86_64
-Section: misc
-Depends: libxml2,jansson,c-ares,sphinx
-Description: nghttp2-1.66.0
-Source: https://github.com/nghttp2/nghttp2/releases/download/v1.66.0/nghttp2-1.66.0.tar.xz
+Section: network
+Depends: openssl,zlib
+Description: HTTP/2 C Library and tools
+Source: https://github.com/nghttp2/nghttp2/releases/download/v1.64.0/nghttp2-1.64.0.tar.gz
 
 [configure]
-./configure --prefix=/opt/hud
+./configure \
+    --prefix=/opt/hud \
+    --enable-lib-only \
+    --disable-python-bindings \
+    PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig" \
+    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
+    CPPFLAGS="-I/opt/hud/include"
 
 [build]
@@ -17,13 +23,7 @@
 
 [install]
-make install
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "nghttp2 1.66.0 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ nghttp2 1.64.0 installed to /opt/hud"
```

</details>


### `openssl`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/o/openssl/openssl-3.5.2.huddef` | 3.5.2 | `94fe4ea9a70a` | `b4b5207a52aa` | **POOL** |
| `sources/definitions/old/packages/openssl-3.4.0.huddef` | 3.4.0 | `6db0a13b2d4e` | `469990126056` | alt |
| `sources/definitions/old/updated-packages/openssl-3.5.2.huddef` | 3.5.2 | `94fe4ea9a70a` | `b4b5207a52aa` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/openssl-3.4.0.huddef</code> (19 added, 13 removed)</summary>

```diff
--- pool/main/o/openssl/openssl-3.5.2.huddef
+++ sources/definitions/old/packages/openssl-3.4.0.huddef
@@ -1,23 +1,29 @@
-# HUD Package Definition - openssl 3.5.2
+# HUD Package Definition - openssl 3.4.0
 # Cryptography and SSL/TLS toolkit
+
 Package: openssl
-Version: 3.5.2
+Version: 3.4.0
 Architecture: x86_64
 Section: security
 Depends: zlib,perl
 Description: Cryptography and SSL/TLS toolkit
-Source: https://github.com/openssl/openssl/releases/download/openssl-3.5.2/openssl-3.5.2.tar.gz
+Source: https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz
+
 [configure]
-./config --prefix=/opt/hud \
-         --openssldir=/opt/hud/etc/ssl \
-         --libdir=lib \
-         shared \
-         zlib-dynamic
+./Configure \
+    --prefix=/opt/hud \
+    --openssldir=/opt/hud/etc/ssl \
+    --libdir=lib \
+    shared \
+    zlib-dynamic \
+    enable-ec_nistp_64_gcc_128 \
+    linux-x86_64
+
 [build]
-make
+make -j$(nproc)
+
 [install]
-sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
-make MANSUFFIX=ssl DESTDIR=$DESTDIR install
-mv -v $DESTDIR/opt/hud/share/doc/openssl $DESTDIR/opt/hud/share/doc/openssl-3.5.2 2>/dev/null || true
+make DESTDIR=$DESTDIR install_sw install_ssldirs
+
 [postinst]
 ldconfig 2>/dev/null || true
@@ -32,4 +38,4 @@
     ln -sf /etc/ssl/certs/ca-certificates.crt /opt/hud/etc/ssl/cert.pem 2>/dev/null || true
 fi
-echo "✓ openssl 3.5.2 installed to /opt/hud"
+echo "✓ openssl 3.4.0 installed to /opt/hud"
 /opt/hud/bin/openssl version 2>/dev/null || true
```

</details>


### `ovirt-engine`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/14 Feb 2026/week4/ovirt-engine-4.5.7.huddef` | 4.5.7 | `2cf4e0d1a5b9` | `afe61c0ed30a` | alt |
| `sources/definitions/old/packages/ovirt-engine-4.5.6.huddef` | 4.5.6 | `14ae75edea92` | `10105b2def44` | alt |
| `sources/definitions/old/updated-packages/ovirt-engine-4.5.6.huddef` | 4.5.6 | `14ae75edea92` | `10105b2def44` | alt |

Diffs below are taken from the first variant, `sources/definitions/14 Feb 2026/week4/ovirt-engine-4.5.7.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/ovirt-engine-4.5.6.huddef</code> (18 added, 285 removed)</summary>

```diff
--- sources/definitions/14 Feb 2026/week4/ovirt-engine-4.5.7.huddef
+++ sources/definitions/old/packages/ovirt-engine-4.5.6.huddef
@@ -1,303 +1,32 @@
-# HUD Package Definition - oVirt Engine 4.5.7
-# Central management server for oVirt virtualization platform
-# MASSIVE PACKAGE: Java-based, requires PostgreSQL, takes 2-3 days to build
-# Reference: https://www.ovirt.org/
+# HUD Package Definition - ovirt-engine 4.5.6
+# Auto-generated for oVirt infrastructure
 
 Package: ovirt-engine
-Version: 4.5.7
+Version: 4.5.6
 Architecture: x86_64
 Section: virtualization
-Depends: postgresql, java-bin, maven, otopi, python3, python3-pyyaml, python3-jinja2, python3-six, ansible-core
-Description: oVirt Engine - Virtualization management server
-Source: https://resources.ovirt.org/pub/ovirt-4.5/src/ovirt-engine/ovirt-engine-4.5.7.tar.gz
+Depends: postgresql,openjdk,apache,wildfly,ansible,python3,ovirt-engine-sdk-python
+Description: oVirt Engine - Central management server for oVirt infrastructure
+Source: https://github.com/oVirt/ovirt-engine/archive/refs/tags/ovirt-engine-4.5.6.tar.gz
+Service: ovirt-engine
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export JAVA_HOME=/opt/hud/lib/java
-export M2_HOME=/opt/hud/share/maven
-export MAVEN_HOME=/opt/hud/share/maven
-export PYTHON=/usr/bin/python3
-
-# Install Python dependencies
-pip3 install --break-system-packages \
-    pyyaml jinja2 six ansible-core netaddr \
-    python-daemon lockfile psycopg2-binary \
-    otopi ovirt-engine-sdk-python
-
-# This is a Maven project - no traditional configure
-echo "oVirt Engine uses Maven build system"
-echo "Build will take 2-3 hours on modern hardware"
+./configure --prefix=/opt/hud
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export JAVA_HOME=/opt/hud/lib/java
-export MAVEN_HOME=/opt/hud/share/maven
-
-# Maven build - this will take a LONG time
-echo "Starting Maven build - this will take 2-3 hours..."
-
-mvn clean install \
-    -DskipTests \
-    -Dgwt.compiler.localWorkers=2 \
-    -Dgwt.compiler.skip=false \
-    -Dmaven.repo.local=$HOME/.m2/repository
+make BUILD_ENV=build PREFIX=/opt/hud
 
 [install]
-# Install to DESTDIR
-make PREFIX=/opt/hud DESTDIR=$DESTDIR install
-
-# Create required directories
-mkdir -p $DESTDIR/etc/ovirt-engine
-mkdir -p $DESTDIR/var/lib/ovirt-engine
-mkdir -p $DESTDIR/var/log/ovirt-engine
-mkdir -p $DESTDIR/var/cache/ovirt-engine
-mkdir -p $DESTDIR/var/tmp/ovirt-engine
-mkdir -p $DESTDIR/usr/share/ovirt-engine
-
-# Copy built artifacts
-cp -r packaging/target/ovirt-engine-*/* $DESTDIR/usr/share/ovirt-engine/
-
-# Install configurations
-cp -r packaging/etc/* $DESTDIR/etc/ovirt-engine/
-
-# Install setup tools
-mkdir -p $DESTDIR/opt/hud/bin
-cp -r packaging/bin/* $DESTDIR/opt/hud/bin/
-
-# Install systemd services
-mkdir -p $DESTDIR/etc/systemd/system
-cp -r packaging/systemd/*.service $DESTDIR/etc/systemd/system/
+make install PREFIX=/opt/hud DESTDIR=$DESTDIR
 
 [postinst]
-# Create ovirt-engine user and group
-groupadd -r ovirt 2>/dev/null || true
-useradd -r -g ovirt -d /var/lib/ovirt-engine \
-    -s /sbin/nologin -c "oVirt Engine User" ovirt 2>/dev/null || true
+ldconfig 2>/dev/null || true
+echo "ovirt-engine 4.5.6 installed to /opt/hud"
 
-# Set ownership
-chown -R ovirt:ovirt /var/lib/ovirt-engine
-chown -R ovirt:ovirt /var/log/ovirt-engine
-chown -R ovirt:ovirt /var/cache/ovirt-engine
-chown -R ovirt:ovirt /var/tmp/ovirt-engine
+[prerm]
+# Stop service if running
+systemctl stop hud-ovirt-engine 2>/dev/null || true
+systemctl disable hud-ovirt-engine 2>/dev/null || true
 
-# Create engine database configuration
-cat > /etc/ovirt-engine/engine.conf.d/10-setup-database.conf << 'EOFCONF'
-# Database configuration
-# Will be configured by engine-setup
-ENGINE_DB_HOST=localhost
-ENGINE_DB_PORT=5432
-ENGINE_DB_USER=engine
-ENGINE_DB_PASSWORD=
-ENGINE_DB_DATABASE=engine
-ENGINE_DB_DRIVER=org.postgresql.Driver
-ENGINE_DB_URL=jdbc:postgresql://${ENGINE_DB_HOST}:${ENGINE_DB_PORT}/${ENGINE_DB_DATABASE}
-EOFCONF
-
-# Create main engine service
-cat > /etc/systemd/system/ovirt-engine.service << 'EOFSVC'
-[Unit]
-Description=oVirt Engine
-Requires=postgresql.service
-After=postgresql.service network.target
-
-[Service]
-Type=simple
-User=ovirt
-Group=ovirt
-EnvironmentFile=/etc/ovirt-engine/ovirt-engine.conf
-ExecStart=/usr/share/ovirt-engine/services/ovirt-engine/ovirt-engine.py \
-    --redirect-output start
-ExecStop=/usr/share/ovirt-engine/services/ovirt-engine/ovirt-engine.py stop
-Restart=on-failure
-RestartSec=10
-TimeoutStartSec=0
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Create engine-notifier service
-cat > /etc/systemd/system/ovirt-engine-notifier.service << 'EOFSVC'
-[Unit]
-Description=oVirt Engine Notifier
-Requires=ovirt-engine.service
-After=ovirt-engine.service
-
-[Service]
-Type=simple
-User=ovirt
-Group=ovirt
-ExecStart=/usr/share/ovirt-engine/services/ovirt-engine-notifier/ovirt-engine-notifier.py start
-Restart=on-failure
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Create engine-dwhd service (data warehouse)
-cat > /etc/systemd/system/ovirt-engine-dwhd.service << 'EOFSVC'
-[Unit]
-Description=oVirt Engine Data Warehouse
-Requires=ovirt-engine.service
-After=ovirt-engine.service
-
-[Service]
-Type=simple
-User=ovirt
-Group=ovirt
-ExecStart=/usr/share/ovirt-engine-dwh/services/ovirt-engine-dwhd/ovirt-engine-dwhd.py start
-Restart=on-failure
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Create engine-health-check service
-cat > /etc/systemd/system/ovirt-engine-healthcheck.service << 'EOFSVC'
-[Unit]
-Description=oVirt Engine Health Check
-Requires=ovirt-engine.service
-After=ovirt-engine.service
-
-[Service]
-Type=oneshot
-User=ovirt
-ExecStart=/usr/share/ovirt-engine/services/ovirt-engine-healthcheck/ovirt-engine-healthcheck.py
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Create firewalld service
-mkdir -p /etc/firewalld/services
-cat > /etc/firewalld/services/ovirt-engine.xml << 'EOFXML'
-<?xml version="1.0" encoding="utf-8"?>
-<service>
-  <short>oVirt Engine</short>
-  <description>oVirt Virtualization Management Engine</description>
-  <port protocol="tcp" port="80"/>
-  <port protocol="tcp" port="443"/>
-  <port protocol="tcp" port="6100"/>
-</service>
-EOFXML
-
-# Add firewall rules
-if systemctl is-active --quiet firewalld; then
-    firewall-cmd --permanent --add-service=ovirt-engine 2>/dev/null || true
-    firewall-cmd --permanent --add-service=http 2>/dev/null || true
-    firewall-cmd --permanent --add-service=https 2>/dev/null || true
-    firewall-cmd --reload 2>/dev/null || true
-fi
-
-# Create PostgreSQL database setup script
-cat > /tmp/setup-engine-db.sh << 'EOFDBSETUP'
-#!/bin/bash
-# oVirt Engine Database Setup
-
-set -e
-
-echo "Setting up PostgreSQL for oVirt Engine..."
-
-# Switch to postgres user and create database
-sudo -u postgres psql << EOFSQL
--- Create engine database user
-CREATE USER engine WITH PASSWORD 'engine123';
-
--- Create engine database
-CREATE DATABASE engine OWNER engine TEMPLATE template0 
-  ENCODING 'UTF8' LC_COLLATE 'en_US.UTF-8' LC_CTYPE 'en_US.UTF-8';
-
--- Grant privileges
-GRANT ALL PRIVILEGES ON DATABASE engine TO engine;
-
--- Create extensions
-\c engine
-CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-
-\q
-EOFSQL
-
-echo "Database 'engine' created successfully"
-echo "User: engine"
-echo "Password: engine123"
-echo ""
-echo "IMPORTANT: Change the default password for production!"
-EOFDBSETUP
-
-chmod +x /tmp/setup-engine-db.sh
-
-# Reload systemd
-systemctl daemon-reload
-
-echo ""
-echo "============================================"
-echo "oVirt Engine 4.5.7 installed successfully"
-echo "============================================"
-echo ""
-echo "██████╗ ██╗      █████╗  ██████╗██╗  ██╗███████╗██╗      █████╗  ██████╗ "
-echo "██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝██╔════╝██║     ██╔══██╗██╔════╝ "
-echo "██████╔╝██║     ███████║██║     █████╔╝ █████╗  ██║     ███████║██║  ███╗"
-echo "██╔══██╗██║     ██╔══██║██║     ██╔═██╗ ██╔══╝  ██║     ██╔══██║██║   ██║"
-echo "██████╔╝███████╗██║  ██║╚██████╗██║  ██╗██║     ███████╗██║  ██║╚██████╔╝"
-echo "╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝ ╚═════╝ "
-echo ""
-echo "        VIRTUALIZATION MANAGEMENT PLATFORM"
-echo ""
-echo "============================================"
-echo ""
-echo "NEXT STEPS:"
-echo ""
-echo "1. Setup PostgreSQL database:"
-echo "   sudo bash /tmp/setup-engine-db.sh"
-echo ""
-echo "2. Run engine-setup (interactive configuration):"
-echo "   sudo engine-setup"
-echo ""
-echo "3. Answer setup questions:"
-echo "   - Configure database connection"
-echo "   - Set admin password"
-echo "   - Configure firewall"
-echo "   - Setup SSL certificates"
-echo ""
-echo "4. After setup completes, access web interface:"
-echo "   https://$(hostname):443/ovirt-engine"
-echo ""
-echo "   Default login: admin@internal"
-echo "   Password: (set during engine-setup)"
-echo ""
-echo "Services installed:"
-echo "  - ovirt-engine.service (main engine)"
-echo "  - ovirt-engine-notifier.service (notifications)"
-echo "  - ovirt-engine-dwhd.service (data warehouse)"
-echo ""
-echo "Firewall ports opened:"
-echo "  - 80/443 (HTTP/HTTPS web interface)"
-echo "  - 6100 (WebSocket proxy)"
-echo ""
-echo "Configuration: /etc/ovirt-engine/"
-echo "Logs: /var/log/ovirt-engine/"
-echo ""
-echo "============================================"
-echo "IMPORTANT SECURITY NOTES:"
-echo "============================================"
-echo ""
-echo "1. The default database password is 'engine123'"
-echo "   Change it immediately for production!"
-echo ""
-echo "2. Configure firewall properly - only allow"
-echo "   access from trusted networks"
-echo ""
-echo "3. Use strong passwords for admin account"
-echo ""
-echo "4. Consider using Let's Encrypt for SSL"
-echo ""
-echo "5. Regular backups with: engine-backup"
-echo ""
-echo "============================================"
-echo ""
-echo "For full documentation, visit:"
-echo "https://www.ovirt.org/documentation/"
-echo ""
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `pango`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/old/0/pango-1.56.3.huddef` | 1.56.3 | `1feaa6e5aa9d` | `456f578b9b22` | alt |
| `sources/definitions/old/packages/pango-1.56.4.huddef` | 1.56.4 | `52c68cc3b14c` | `b131b89fe4ce` | alt |
| `sources/definitions/old/updated-packages/pango-1.56.4.huddef` | 1.56.4 | `52c68cc3b14c` | `b131b89fe4ce` | alt |

Diffs below are taken from the first variant, `sources/definitions/old/0/pango-1.56.3.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/pango-1.56.4.huddef</code> (23 added, 16 removed)</summary>

```diff
--- sources/definitions/old/0/pango-1.56.3.huddef
+++ sources/definitions/old/packages/pango-1.56.4.huddef
@@ -1,22 +1,29 @@
-# HUD Package Definition - pango 1.56.3
-# Text layout and rendering library
+# HUD Package Definition - pango 1.56.4
+# Auto-generated for oVirt infrastructure
+
 Package: pango
-Version: 1.56.3
+Version: 1.56.4
 Architecture: x86_64
-Section: graphics
-Depends: glib,harfbuzz,fontconfig,fribidi,cairo
-Description: Library for layout and rendering of text
-Source: https://download.gnome.org/sources/pango/1.56/pango-1.56.3.tar.xz
+Section: misc
+Depends: freetype2,gi-docgen,glib2,fontconfig,harfbuzz,xorg7-lib,cairo
+Description: Pango-1.56.4
+Source: https://download.gnome.org/sources/pango/1.56/pango-1.56.4.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ pango 1.56.3 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "pango 1.56.4 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `perl`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/perl/perl-5.42.0.huddef` | 5.42.0 | `51261ae53978` | `433402d54d1e` | **POOL** |
| `sources/definitions/old/packages/perl-5.40.0.huddef` | 5.40.0 | `2b80cd0a412a` | `9433f297526e` | alt |
| `sources/definitions/old/updated-packages/perl-5.42.0.huddef` | 5.42.0 | `51261ae53978` | `433402d54d1e` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/perl-5.40.0.huddef</code> (18 added, 18 removed)</summary>

```diff
--- pool/main/p/perl/perl-5.42.0.huddef
+++ sources/definitions/old/packages/perl-5.40.0.huddef
@@ -1,30 +1,30 @@
-# HUD Package Definition - perl 5.42.0
+# HUD Package Definition - perl 5.40.0
 # Practical Extraction and Report Language
+
 Package: perl
-Version: 5.42.0
+Version: 5.40.0
 Architecture: x86_64
 Section: development
 Depends: zlib
-Description: Practical Extraction and Report Language - programming language
-Source: https://www.cpan.org/src/5.0/perl-5.42.0.tar.xz
+Description: The Perl programming language
+Source: https://www.cpan.org/src/5.0/perl-5.40.0.tar.gz
+
 [configure]
 sh Configure -des \
-             -D prefix=/opt/hud \
-             -D vendorprefix=/opt/hud \
-             -D useshrplib \
-             -D privlib=/opt/hud/lib/perl5/5.42/core_perl \
-             -D archlib=/opt/hud/lib/perl5/5.42/core_perl \
-             -D sitelib=/opt/hud/lib/perl5/5.42/site_perl \
-             -D sitearch=/opt/hud/lib/perl5/5.42/site_perl \
-             -D vendorlib=/opt/hud/lib/perl5/5.42/vendor_perl \
-             -D vendorarch=/opt/hud/lib/perl5/5.42/vendor_perl \
-             -D man1dir=/opt/hud/share/man/man1 \
-             -D man3dir=/opt/hud/share/man/man3 \
-             -D pager="/usr/bin/less -isR"
+    -Dprefix=/opt/hud \
+    -Dvendorprefix=/opt/hud \
+    -Dman1dir=/opt/hud/share/man/man1 \
+    -Dman3dir=/opt/hud/share/man/man3 \
+    -Dpager="/usr/bin/less -isR" \
+    -Duseshrplib \
+    -Dusethreads
+
 [build]
-make
+make -j$(nproc)
+
 [install]
 make DESTDIR=$DESTDIR install
+
 [postinst]
-echo "✓ perl 5.42.0 installed to /opt/hud"
+echo "✓ perl 5.40.0 installed to /opt/hud"
 /opt/hud/bin/perl -v 2>/dev/null | head -2 || true
```

</details>


### `python-requests`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/networkmanager-huddef-packages/python-requests-2.32.5.huddef` | 2.32.5 | `de5918a08978` | `2aea1128eae4` | alt |
| `sources/definitions/old/updated-packages/python-requests-2.32.3.huddef` | 2.32.3 | `5d75417d2dea` | `6dab89f51e50` | alt |

Diffs below are taken from the first variant, `sources/definitions/networkmanager-huddef-packages/python-requests-2.32.5.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/updated-packages/python-requests-2.32.3.huddef</code> (11 added, 22 removed)</summary>

```diff
--- sources/definitions/networkmanager-huddef-packages/python-requests-2.32.5.huddef
+++ sources/definitions/old/updated-packages/python-requests-2.32.3.huddef
@@ -1,33 +1,22 @@
-# HUD Package Definition - requests 2.32.5
-# HTTP library for Python
-# Elegant and simple HTTP library
+# HUD Package Definition - requests 2.32.3
+# Python HTTP library
 
 Package: python-requests
-Version: 2.32.5
+Version: 2.32.3
 Architecture: x86_64
-Section: python
-Depends: python, python-charset-normalizer, python-idna, python-urllib3, make-ca
-Description: HTTP library for Python - simple and elegant
-Source: https://files.pythonhosted.org/packages/source/r/requests/requests-2.32.5.tar.gz
-Patch: https://www.linuxfromscratch.org/patches/blfs/12.4/requests-use_system_certs-1.patch
+Section: python-modules
+Depends: python3, python-urllib3, python-certifi, python-charset-normalizer, python-idna
+Description: Python HTTP library for humans
+Source: https://files.pythonhosted.org/packages/source/r/requests/requests-2.32.3.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-
-# Apply patch to use system certificates
-if [ -f ../requests-use_system_certs-1.patch ]; then
-    patch -Np1 -i ../requests-use_system_certs-1.patch
-fi
+# No configure needed
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
+/opt/hud/bin/python3 -m build --wheel --no-isolation
 
 [install]
-pip3 install --no-index --find-links dist --no-user --root=$DESTDIR requests
+/opt/hud/bin/pip3 install --no-deps --prefix=/opt/hud --root=$DESTDIR dist/*.whl
 
 [postinst]
-echo "✓ Python requests 2.32.5 installed"
-echo "  Note: Uses system certificates via make-ca"
+echo "✓ requests 2.32.3 installed to /opt/hud"
```

</details>


### `python-setuptools`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/p/python-setuptools/python-setuptools-80.9.0.huddef` | 80.9.0 | `9fc7acb721e6` | `a4aaf651b763` | **POOL** |
| `sources/definitions/networkmanager-huddef-packages/python-setuptools-80.9.0.huddef` | 80.9.0 | `9fc7acb721e6` | `a4aaf651b763` | **= POOL** |
| `sources/definitions/old/updated-packages/python-setuptools-78.1.0.huddef` | 78.1.0 | `98eaa813a0e6` | `eb9d785937ea` | alt |

<details><summary>diff → <code>sources/definitions/old/updated-packages/python-setuptools-78.1.0.huddef</code> (11 added, 15 removed)</summary>

```diff
--- pool/main/p/python-setuptools/python-setuptools-80.9.0.huddef
+++ sources/definitions/old/updated-packages/python-setuptools-78.1.0.huddef
@@ -1,26 +1,22 @@
-# HUD Package Definition - setuptools 80.9.0
-# Python packaging and distribution tools
-# Required by many build systems including meson for g-i
+# HUD Package Definition - setuptools 78.1.0
+# Python packaging tools
 
 Package: python-setuptools
-Version: 80.9.0
+Version: 78.1.0
 Architecture: x86_64
-Section: python
-Depends: python
-Description: Python packaging and distribution tools
-Source: https://files.pythonhosted.org/packages/source/s/setuptools/setuptools-80.9.0.tar.gz
+Section: python-modules
+Depends: python3
+Description: Python package distribution utilities
+Source: https://files.pythonhosted.org/packages/source/s/setuptools/setuptools-78.1.0.tar.gz
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
+# No configure needed
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir $PWD
+/opt/hud/bin/python3 -m build --wheel --no-isolation
 
 [install]
-pip3 install --no-index --find-links dist --no-user --root=$DESTDIR setuptools
+/opt/hud/bin/pip3 install --no-deps --prefix=/opt/hud --root=$DESTDIR dist/*.whl
 
 [postinst]
-echo "✓ Python setuptools 80.9.0 installed"
+echo "✓ setuptools 78.1.0 installed to /opt/hud"
```

</details>


### `readline`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/r/readline/readline-8.3.huddef` | 8.3 | `6120cde357b2` | `0aa722fe7484` | **POOL** |
| `sources/definitions/old/packages/readline-8.2.13.huddef` | 8.2.13 | `c57634b5e938` | `0216c527ab6e` | alt |
| `sources/definitions/old/updated-packages/readline-8.2.13.huddef` | 8.3 | `6120cde357b2` | `0aa722fe7484` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/readline-8.2.13.huddef</code> (12 added, 12 removed)</summary>

```diff
--- pool/main/r/readline/readline-8.3.huddef
+++ sources/definitions/old/packages/readline-8.2.13.huddef
@@ -1,28 +1,28 @@
-# HUD Package Definition - readline 8.3
+# HUD Package Definition - readline 8.2.13
 # GNU readline library
+
 Package: readline
-Version: 8.3
+Version: 8.2.13
 Architecture: x86_64
 Section: libraries
 Depends: ncurses
 Description: GNU Readline library for command line editing
-Source: https://ftp.gnu.org/gnu/readline/readline-8.3.tar.gz
+Source: https://ftp.gnu.org/gnu/readline/readline-8.2.13.tar.gz
+
 [configure]
-sed -i '/MV.*old/d' Makefile.in
-sed -i '/{OLDSUFF}/c:' support/shlib-install
-sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
 ./configure \
     --prefix=/opt/hud \
     --disable-static \
     --with-curses \
-    --docdir=/opt/hud/share/doc/readline-8.3 \
-    CPPFLAGS="-I/opt/hud/include -I/opt/hud/include/ncursesw" \
-    LDFLAGS="-L/opt/hud/lib"
+    LDFLAGS="-L/opt/hud/lib -Wl,-rpath,/opt/hud/lib" \
+    CPPFLAGS="-I/opt/hud/include -I/opt/hud/include/ncursesw"
+
 [build]
-make SHLIB_LIBS="-lncursesw"
+make SHLIB_LIBS="-lncursesw" -j$(nproc)
+
 [install]
 make SHLIB_LIBS="-lncursesw" DESTDIR=$DESTDIR install
-install -v -m644 doc/*.{ps,pdf,html,dvi} $DESTDIR/opt/hud/share/doc/readline-8.3 2>/dev/null || true
+
 [postinst]
 ldconfig 2>/dev/null || true
-echo "✓ readline 8.3 installed to /opt/hud"
+echo "✓ readline 8.2.13 installed to /opt/hud"
```

</details>


### `sanlock`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/s/sanlock/sanlock-3.9.5.huddef` | 3.9.5 | `ea280c20d999` | `5cc96ea83b1f` | **POOL** |
| `sources/definitions/14 Feb 2026/sanlock-3.9.5.huddef` | 3.9.5 | `ea280c20d999` | `5cc96ea83b1f` | **= POOL** |
| `sources/definitions/old/packages/sanlock-3.9.4.huddef` | 3.9.4 | `54c5fd015f01` | `d0bbd2bf231c` | alt |
| `sources/definitions/old/updated-packages/sanlock-3.9.4.huddef` | 3.9.4 | `54c5fd015f01` | `d0bbd2bf231c` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/sanlock-3.9.4.huddef</code> (18 added, 86 removed)</summary>

```diff
--- pool/main/s/sanlock/sanlock-3.9.5.huddef
+++ sources/definitions/old/packages/sanlock-3.9.4.huddef
@@ -1,100 +1,32 @@
-# HUD Package Definition - sanlock 3.9.5
-# Shared storage lock manager for virtual machines
-# CRITICAL: Prevents VM disk corruption during live migration and failover
-# Required by: libvirt, oVirt, cluster storage
-# Reference: https://pagure.io/sanlock
+# HUD Package Definition - sanlock 3.9.4
+# Auto-generated for oVirt infrastructure
 
 Package: sanlock
-Version: 3.9.5
+Version: 3.9.4
 Architecture: x86_64
 Section: virtualization
-Depends: libaio, python3
-Description: Shared storage lock manager for virtual machines
-Source: https://releases.pagure.org/sanlock/sanlock-3.9.5.tar.gz
+Depends: libaio,libuuid,python3
+Description: Shared storage lock manager
+Source: https://pagure.io/sanlock/archive/sanlock-3.9.4/sanlock-sanlock-3.9.4.tar.gz
+Service: sanlock
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export CFLAGS="-I/opt/hud/include"
-export LDFLAGS="-L/opt/hud/lib -L/opt/hud/lib64"
-
-# No configure script - uses plain Makefile
-echo "Sanlock uses Makefile build system"
+./configure --prefix=/opt/hud
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-
-# Build sanlock
-make -j$(nproc) \
-    PREFIX=/opt/hud \
-    LIBDIR=/opt/hud/lib64 \
-    PYTHON=/usr/bin/python3
+make -C wdmd && make -C src && make -C python
 
 [install]
-make DESTDIR=$DESTDIR \
-    PREFIX=/opt/hud \
-    LIBDIR=/opt/hud/lib64 \
-    install
-
-# Install Python bindings
-cd python
-python3 setup.py install --prefix=/opt/hud --root=$DESTDIR
-
-# Create directories
-mkdir -p $DESTDIR/var/run/sanlock
-mkdir -p $DESTDIR/var/lib/sanlock
-mkdir -p $DESTDIR/etc/sanlock
+make -C wdmd DESTDIR=$DESTDIR PREFIX=/opt/hud install && make -C src DESTDIR=$DESTDIR PREFIX=/opt/hud install
 
 [postinst]
-# Add library path
-echo "/opt/hud/lib64" > /etc/ld.so.conf.d/sanlock.conf
-ldconfig
+ldconfig 2>/dev/null || true
+echo "sanlock 3.9.4 installed to /opt/hud"
 
-# Create sanlock user and group
-groupadd -r sanlock 2>/dev/null || true
-useradd -r -g sanlock -d /var/lib/sanlock -s /sbin/nologin \
-    -c "sanlock lock manager" sanlock 2>/dev/null || true
+[prerm]
+# Stop service if running
+systemctl stop hud-sanlock 2>/dev/null || true
+systemctl disable hud-sanlock 2>/dev/null || true
 
-# Set ownership
-chown -R sanlock:sanlock /var/run/sanlock
-chown -R sanlock:sanlock /var/lib/sanlock
-
-# Create systemd service
-cat > /etc/systemd/system/sanlock.service << 'EOFSVC'
-[Unit]
-Description=Shared Storage Lock Manager
-Requires=network.target
-After=network.target
-Documentation=man:sanlock(8)
-
-[Service]
-Type=forking
-ExecStart=/opt/hud/sbin/sanlock daemon
-ExecStop=/bin/kill -TERM $MAINPID
-User=sanlock
-Group=sanlock
-PIDFile=/var/run/sanlock/sanlock.pid
-Restart=on-failure
-RestartSec=5
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-systemctl daemon-reload
-systemctl enable sanlock.service
-systemctl start sanlock.service || true
-
-echo ""
-echo "============================================"
-echo "sanlock 3.9.5 installed successfully"
-echo "============================================"
-echo ""
-echo "Service: systemctl status sanlock"
-echo "Verify: /opt/hud/sbin/sanlock status"
-echo ""
-echo "CRITICAL: This package prevents VM corruption"
-echo "during live migration and cluster failover"
-echo ""
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `sqlite`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/s/sqlite/sqlite-3.50.4.huddef` | 3.50.4 | `07b7d31e94ad` | `2a381612ee39` | **POOL** |
| `sources/definitions/old/packages/sqlite-3.48.0.huddef` | 3.48.0 | `49bd20b2aa1e` | `5465a9b17e72` | alt |
| `sources/definitions/old/packages/sqlite-3.50.4.huddef` | 3.50.4 | `07b7d31e94ad` | `2a381612ee39` | **= POOL** |
| `sources/definitions/old/updated-packages/sqlite-3.50.4.huddef` | 3.50.4 | `07b7d31e94ad` | `2a381612ee39` | **= POOL** |

<details><summary>diff → <code>sources/definitions/old/packages/sqlite-3.48.0.huddef</code> (21 added, 15 removed)</summary>

```diff
--- pool/main/s/sqlite/sqlite-3.50.4.huddef
+++ sources/definitions/old/packages/sqlite-3.48.0.huddef
@@ -1,15 +1,26 @@
-# HUD Package Definition - sqlite 3.50.4
-# Auto-generated for oVirt infrastructure
+# HUD Package Definition - sqlite 3.48.0
+# SQL database engine
 
 Package: sqlite
-Version: 3.50.4
+Version: 3.48.0
 Architecture: x86_64
 Section: databases
-Depends: 
-Description: SQLite-3.50.4
-Source: https://sqlite.org/2025/sqlite-autoconf-3500400.tar.gz
+Depends: zlib,readline
+Description: Self-contained, serverless SQL database engine
+Source: https://sqlite.org/2025/sqlite-autoconf-3480000.tar.gz
 
 [configure]
-./configure --prefix=/opt/hud --enable-fts5 --enable-session
+./configure \
+    --prefix=/opt/hud \
+    --disable-static \
+    --enable-fts5 \
+    --enable-session \
+    CPPFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA=1 \
+              -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 \
+              -DSQLITE_ENABLE_DBSTAT_VTAB=1 \
+              -DSQLITE_ENABLE_FTS3_TOKENIZER=1 \
+              -DSQLITE_SECURE_DELETE=1 \
+              -DSQLITE_ENABLE_FTS3=1 \
+              -DSQLITE_MAX_VARIABLE_NUMBER=250000"
 
 [build]
@@ -17,13 +28,8 @@
 
 [install]
-make install
+make DESTDIR=$DESTDIR install
 
 [postinst]
 ldconfig 2>/dev/null || true
-echo "sqlite 3.50.4 installed to /opt/hud"
-
-[prerm]
-# Stop service if running
-
-[postrm]
-ldconfig 2>/dev/null || true
+echo "✓ sqlite 3.48.0 installed to /opt/hud"
+/opt/hud/bin/sqlite3 --version 2>/dev/null || true
```

</details>


### `vdsm`

> **No pool copy — no tiebreaker.** This package was never published, so nothing on disk proves which variant is authoritative.

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `sources/definitions/14 Feb 2026/week3/vdsm-4.50.7.huddef` | 4.50.7 | `9e88f52bf069` | `29583775c83e` | alt |
| `sources/definitions/old/packages/vdsm-4.50.6.huddef` | 4.50.6 | `2dec67381dbf` | `42e90096619d` | alt |
| `sources/definitions/old/updated-packages/vdsm-4.50.6.huddef` | 4.50.6 | `2dec67381dbf` | `42e90096619d` | alt |

Diffs below are taken from the first variant, `sources/definitions/14 Feb 2026/week3/vdsm-4.50.7.huddef`, for want of a pool copy.

<details><summary>diff → <code>sources/definitions/old/packages/vdsm-4.50.6.huddef</code> (18 added, 215 removed)</summary>

```diff
--- sources/definitions/14 Feb 2026/week3/vdsm-4.50.7.huddef
+++ sources/definitions/old/packages/vdsm-4.50.6.huddef
@@ -1,229 +1,32 @@
-# HUD Package Definition - VDSM 4.50.7
-# Virtual Desktop and Server Manager - oVirt node management daemon
-# CRITICAL COMPONENT: This is the core hypervisor management agent
-# Reference: https://github.com/oVirt/vdsm
+# HUD Package Definition - vdsm 4.50.6
+# Auto-generated for oVirt infrastructure
 
 Package: vdsm
-Version: 4.50.7
+Version: 4.50.6
 Architecture: x86_64
 Section: virtualization
-Depends: python3, libvirt, qemu, sanlock, mom, python3-six, python3-yaml, python3-decorator, python3-netaddr, iproute2
-Description: Virtual Desktop and Server Manager for oVirt
-Source: https://resources.ovirt.org/pub/ovirt-4.5/src/vdsm/vdsm-4.50.7.tar.gz
+Depends: python3,libvirt,qemu,sanlock,glusterfs,ovirt-imageio
+Description: Virtual Desktop Server Manager - oVirt host agent
+Source: https://github.com/oVirt/vdsm/archive/refs/tags/v4.50.6.tar.gz
+Service: vdsmd
 
 [configure]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export PKG_CONFIG_PATH="/opt/hud/lib/pkgconfig:/opt/hud/lib64/pkgconfig:${PKG_CONFIG_PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-export PYTHON=/usr/bin/python3
-
-# Install Python dependencies
-pip3 install --break-system-packages \
-    six pyyaml decorator netaddr requests \
-    libvirt-python ioprocess cpopen
-
-./configure --prefix=/opt/hud \
-            --sysconfdir=/etc \
-            --localstatedir=/var \
-            --with-qemu-user=qemu \
-            --with-qemu-group=qemu \
-            --with-vdsm-user=vdsm \
-            --with-vdsm-group=kvm
+./autogen.sh --prefix=/opt/hud --sysconfdir=/opt/hud/etc
 
 [build]
-export PATH="/opt/hud/bin:/opt/hud/sbin:${PATH}"
-export LD_LIBRARY_PATH="/opt/hud/lib:/opt/hud/lib64:${LD_LIBRARY_PATH}"
-
-make -j$(nproc)
+make
 
 [install]
 make DESTDIR=$DESTDIR install
 
-# Install Python modules
-cd lib/vdsm
-python3 setup.py install --prefix=/opt/hud --root=$DESTDIR
+[postinst]
+ldconfig 2>/dev/null || true
+echo "vdsm 4.50.6 installed to /opt/hud"
 
-[postinst]
-# Create vdsm user and group
-groupadd -r vdsm 2>/dev/null || true
-useradd -r -g vdsm -G kvm,qemu,sanlock,disk -d /var/lib/vdsm \
-    -s /sbin/nologin -c "oVirt VDSM User" vdsm 2>/dev/null || true
+[prerm]
+# Stop service if running
+systemctl stop hud-vdsmd 2>/dev/null || true
+systemctl disable hud-vdsmd 2>/dev/null || true
 
-# Create directories
-mkdir -p /var/lib/vdsm
-mkdir -p /var/log/vdsm
-mkdir -p /var/run/vdsm
-mkdir -p /var/run/vdsm/storage
-mkdir -p /var/run/vdsm/payload
-mkdir -p /etc/vdsm
-
-# Set ownership
-chown -R vdsm:kvm /var/lib/vdsm
-chown -R vdsm:kvm /var/log/vdsm
-chown -R vdsm:kvm /var/run/vdsm
-
-# Create VDSM configuration
-cat > /etc/vdsm/vdsm.conf << 'EOFCONF'
-[vars]
-trust_store_path = /etc/pki/vdsm
-ssl_enabled = true
-
-[addresses]
-management_port = 54321
-
-[mom]
-conf = /etc/vdsm/mom.conf
-
-[irs]
-irs_enable = true
-
-[sampling]
-enable = true
-EOFCONF
-
-# Create MOM configuration for VDSM
-cat > /etc/vdsm/mom.conf << 'EOFMOM'
-[main]
-controllers = KSM, Balloon
-
-[KSM]
-enabled = 1
-
-[Balloon]
-enabled = 1
-EOFMOM
-
-# Create systemd services
-
-# Main VDSM service
-cat > /etc/systemd/system/vdsmd.service << 'EOFSVC'
-[Unit]
-Description=Virtual Desktop Server Manager
-Requires=multipathd.service libvirtd.service time-sync.target \
-         iscsid.service sanlock.service supervdsmd.service mom.service
-After=multipathd.service libvirtd.service sanlock.service supervdsmd.service
-Before=libvirt-guests.service
-
-[Service]
-Type=simple
-LimitCORE=infinity
-LimitNOFILE=4096
-EnvironmentFile=-/etc/sysconfig/vdsm
-ExecStartPre=/opt/hud/libexec/vdsm/vdsmd_init_common.sh --pre-start
-ExecStart=/opt/hud/share/vdsm/vdsmd --run
-ExecStopPost=/opt/hud/libexec/vdsm/vdsmd_init_common.sh --post-stop
-Restart=always
-RestartSec=5
-KillMode=process
-User=vdsm
-Group=kvm
-TimeoutStopSec=30
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Supervisor service
-cat > /etc/systemd/system/supervdsmd.service << 'EOFSVC'
-[Unit]
-Description=Auxiliary vdsm service required by vdsmd
-PartOf=vdsmd.service
-
-[Service]
-Type=simple
-ExecStart=/opt/hud/bin/supervdsmd
-Restart=always
-User=vdsm
-Group=kvm
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Network service
-cat > /etc/systemd/system/vdsm-network.service << 'EOFSVC'
-[Unit]
-Description=VDSM network restoration
-Before=vdsmd.service
-
-[Service]
-Type=oneshot
-ExecStart=/opt/hud/libexec/vdsm/vdsm-restore-net-config
-RemainAfterExit=yes
-
-[Install]
-WantedBy=multi-user.target
-EOFSVC
-
-# Configure libvirt for VDSM
-cat > /etc/libvirt/qemu.conf.d/vdsm.conf << 'EOFLIBVIRT'
-# VDSM libvirt configuration
-user = "vdsm"
-group = "kvm"
-dynamic_ownership = 1
-save_image_format = "lzop"
-dump_image_format = "lzop"
-stdio_handler = "file"
-EOFLIBVIRT
-
-# Configure libvirt daemon for VDSM
-cat > /etc/libvirt/libvirtd.conf.d/vdsm.conf << 'EOFLIBVIRT'
-# VDSM libvirtd configuration
-listen_tls = 0
-listen_tcp = 1
-tcp_port = "16509"
-auth_tcp = "none"
-listen_addr = "0.0.0.0"
-mdns_adv = 0
-EOFLIBVIRT
-
-# Create firewalld service
-mkdir -p /etc/firewalld/services
-cat > /etc/firewalld/services/vdsm.xml << 'EOFXML'
-<?xml version="1.0" encoding="utf-8"?>
-<service>
-  <short>VDSM</short>
-  <description>oVirt Virtual Desktop and Server Manager</description>
-  <port protocol="tcp" port="54321"/>
-  <port protocol="tcp" port="16514"/>
-  <port protocol="tcp" port="49152-49216"/>
-</service>
-EOFXML
-
-# Add firewall rules if firewalld is running
-if systemctl is-active --quiet firewalld; then
-    firewall-cmd --permanent --add-service=vdsm 2>/dev/null || true
-    firewall-cmd --reload 2>/dev/null || true
-fi
-
-# Enable services
-systemctl daemon-reload
-systemctl enable supervdsmd.service
-systemctl enable vdsm-network.service
-systemctl enable vdsmd.service
-
-echo ""
-echo "============================================"
-echo "VDSM 4.50.7 installed successfully"
-echo "============================================"
-echo ""
-echo "CRITICAL: This is the core oVirt hypervisor agent"
-echo ""
-echo "Services created:"
-echo "  - vdsmd.service (main daemon)"
-echo "  - supervdsmd.service (supervisor)"
-echo "  - vdsm-network.service (network restore)"
-echo ""
-echo "Configuration: /etc/vdsm/vdsm.conf"
-echo ""
-echo "IMPORTANT: Do NOT start services yet"
-echo "Wait for oVirt Engine installation and setup"
-echo ""
-echo "The engine will configure and start VDSM when"
-echo "you add this host to the cluster"
-echo ""
-echo "Firewall ports opened:"
-echo "  - 54321 (VDSM management)"
-echo "  - 16514 (libvirt TLS)"
-echo "  - 49152-49216 (VM migration)"
-echo ""
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


### `wayland`

| Copy | Version | sha256 | md5 | |
|---|---|---|---|---|
| `pool/main/w/wayland/wayland-1.23.1.huddef` | 1.23.1 | `bfd52c47b30d` | `2782763eff80` | **POOL** |
| `sources/definitions/old/0/wayland-1.23.1.huddef` | 1.23.1 | `bfd52c47b30d` | `2782763eff80` | **= POOL** |
| `sources/definitions/old/packages/wayland-1.24.0.huddef` | 1.24.0 | `c3a7c656b389` | `1c4387e4441f` | alt |
| `sources/definitions/old/updated-packages/wayland-1.23.1.huddef` | 1.23.1 | `bfd52c47b30d` | `2782763eff80` | **= POOL** |
| `sources/definitions/old/updated-packages/wayland-1.24.0.huddef` | 1.24.0 | `c3a7c656b389` | `1c4387e4441f` | alt |

<details><summary>diff → <code>sources/definitions/old/packages/wayland-1.24.0.huddef</code> (22 added, 15 removed)</summary>

```diff
--- pool/main/w/wayland/wayland-1.23.1.huddef
+++ sources/definitions/old/packages/wayland-1.24.0.huddef
@@ -1,22 +1,29 @@
-# HUD Package Definition - wayland 1.23.1
-# Wayland display server protocol
+# HUD Package Definition - wayland 1.24.0
+# Auto-generated for oVirt infrastructure
+
 Package: wayland
-Version: 1.23.1
+Version: 1.24.0
 Architecture: x86_64
 Section: graphics
-Depends: libxml2,libffi,expat
-Description: Wayland display server protocol library
-Source: https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.1/downloads/wayland-1.23.1.tar.xz
+Depends: xmlto,doxygen,libxslt,libxml2,docbook
+Description: Wayland-1.24.0
+Source: https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.24.0/downloads/wayland-1.24.0.tar.xz
+
 [configure]
-mkdir -p build
-cd build
-meson setup --prefix=/opt/hud --buildtype=release -Ddocumentation=false ..
+./configure --prefix=/opt/hud
+
 [build]
-cd build
-ninja
+make -j$(nproc)
+
 [install]
-cd build
-DESTDIR=$DESTDIR ninja install
+make install
+
 [postinst]
-echo "✓ wayland 1.23.1 installed to /opt/hud"
-/sbin/ldconfig
+ldconfig 2>/dev/null || true
+echo "wayland 1.24.0 installed to /opt/hud"
+
+[prerm]
+# Stop service if running
+
+[postrm]
+ldconfig 2>/dev/null || true
```

</details>


---

# IDENTICAL — 64 packages

Every copy is byte-identical, so consolidation can take any of them.

| Package | Copies | sha256 | Matches pool |
|---|---|---|---|
| `acl` | 2 | `252291acfdd4` | yes |
| `ansible` | 2 | `01e9fb3b5806` | no pool copy |
| `apache` | 2 | `ba76a9fb1142` | no pool copy |
| `attr` | 2 | `384d251e1a9d` | yes |
| `brotli` | 2 | `254a770b30aa` | yes |
| `cockpit` | 2 | `385717ff596a` | no pool copy |
| `cockpit-ovirt` | 2 | `a87d1e1a85ff` | no pool copy |
| `cracklib` | 2 | `749f37eb3c4f` | yes |
| `cryptography` | 2 | `d07c639a617e` | no pool copy |
| `dejavu-fonts` | 2 | `e375d67b4456` | yes |
| `dmidecode` | 2 | `0fce7140a6c2` | yes |
| `dnsmasq` | 2 | `e2f5737a6ca7` | yes |
| `elogind` | 2 | `eb9fc940c8ff` | no pool copy |
| `flac` | 2 | `687709fb61e2` | yes |
| `font-alias` | 2 | `8b4c49bea7ed` | yes |
| `font-util` | 2 | `5f03e99459f9` | yes |
| `fuse3` | 2 | `4aeafe87d234` | no pool copy |
| `gdb` | 2 | `cdd9de826194` | yes |
| `git` | 2 | `98c3e3e0014c` | yes |
| `graphene` | 2 | `76abc6106ed0` | yes |
| `jansson` | 2 | `0e7eea4fe86f` | yes |
| `jinja2` | 2 | `389a609bdf7b` | no pool copy |
| `libcap` | 2 | `657b1d785989` | yes |
| `liberation-fonts` | 2 | `f991125d8a58` | yes |
| `libev` | 2 | `e5d71be79a96` | yes |
| `libibverbs` | 2 | `2863831a0a9a` | yes |
| `libjpeg-turbo` | 2 | `032a092909fa` | yes |
| `libmnl` | 2 | `d2ca77e42945` | yes |
| `libnftnl` | 2 | `679f59f3e8eb` | yes |
| `libnl` | 2 | `4dd0ee20a617` | yes |
| `libogg` | 2 | `92b4d6828e7a` | yes |
| `libpciaccess` | 2 | `e475c79fb729` | yes |
| `libseat` | 2 | `7f9fc2c50903` | yes |
| `libssh` | 2 | `771eb4d735e5` | no pool copy |
| `libssh2` | 2 | `6767a6b7a3bb` | yes |
| `libuuid` | 2 | `7d28ddf61453` | no pool copy |
| `libwebp` | 2 | `379d4c9ad9c7` | yes |
| `libyaml` | 2 | `dcaac790ad6f` | yes |
| `markupsafe` | 2 | `a090ac9e20ca` | no pool copy |
| `mtdev` | 2 | `859810fae298` | yes |
| `nodejs` | 2 | `f7b4b227b69b` | yes |
| `opus` | 2 | `3b8192a5aab2` | yes |
| `ovirt-ansible-collection` | 2 | `70c922416127` | no pool copy |
| `ovirt-dwh` | 2 | `685215f082cb` | no pool copy |
| `ovirt-engine-sdk-python` | 2 | `b39fe46d164b` | no pool copy |
| `ovirt-hosted-engine-ha` | 2 | `962e3afc74f8` | no pool copy |
| `ovirt-hosted-engine-setup` | 2 | `0ed133958cf0` | no pool copy |
| `ovirt-imageio` | 2 | `0fc06730d2f6` | no pool copy |
| `ovirt-web-ui` | 2 | `6dcfc82917a2` | no pool copy |
| `postgresql-ha` | 2 | `15ccf3110586` | yes |
| `postgresql-ldap-ha` | 2 | `fe79e97ac112` | yes |
| `python3` | 2 | `0e4920a468eb` | **no — pool differs** |
| `pyyaml` | 2 | `1d5218d8cdcc` | no pool copy |
| `rdma-core` | 2 | `0ecbdb1c2e4f` | yes |
| `shadow` | 2 | `aeb0c2b16e69` | no pool copy |
| `valgrind` | 2 | `b9474049d9fd` | yes |
| `vim` | 2 | `2d7d8ad6f010` | yes |
| `wildfly` | 2 | `2047fcf3e1c1` | no pool copy |
| `xbitmaps` | 2 | `b17d13a1e1a3` | yes |
| `xcb-proto` | 2 | `7df32ab5cdd7` | yes |
| `xkeyboard-config` | 2 | `61dbc0394537` | yes |
| `xorgproto` | 2 | `173fb8449f96` | yes |
| `xtrans` | 2 | `df8f4fbb12c4` | yes |
| `xz` | 2 | `8f8fd0b097ed` | yes |

---

# ORPHANED — 176 packages

A definition exists but no package was ever published to `pool/`. These have no
tiebreaker and are not part of the 245 shipped packages.

| Package | Copies | Distinct contents |
|---|---|---|
| `adwaita-icon-theme` | 1 | 1 |
| `ansible` | 2 | 1 |
| `apache` | 2 | 1 |
| `at-spi2-core` | 1 | 1 |
| `atk` | 1 | 1 |
| `cairo` | 3 | 2 |
| `cockpit` | 2 | 1 |
| `cockpit-ovirt` | 2 | 1 |
| `corosync` | 1 | 1 |
| `cryptography` | 2 | 1 |
| `dmenu` | 1 | 1 |
| `elogind` | 2 | 1 |
| `encodings` | 1 | 1 |
| `fence-agents` | 1 | 1 |
| `fuse3` | 2 | 1 |
| `gcc` | 1 | 1 |
| `gdk-pixbuf` | 3 | 2 |
| `ghostscript` | 1 | 1 |
| `glib2` | 3 | 2 |
| `graphite2` | 1 | 1 |
| `gst-plugins-base` | 1 | 1 |
| `gtk3` | 3 | 2 |
| `gtk4` | 1 | 1 |
| `hicolor-icon-theme` | 1 | 1 |
| `i3` | 1 | 1 |
| `iscsi-initiator-utils` | 1 | 1 |
| `jinja2` | 2 | 1 |
| `libFS` | 1 | 1 |
| `libXScrnSaver` | 1 | 1 |
| `libXaw` | 1 | 1 |
| `libXcomposite` | 1 | 1 |
| `libXcursor` | 1 | 1 |
| `libXdamage` | 1 | 1 |
| `libXfont2` | 1 | 1 |
| `libXft` | 1 | 1 |
| `libXinerama` | 1 | 1 |
| `libXmu` | 1 | 1 |
| `libXpm` | 1 | 1 |
| `libXpresent` | 1 | 1 |
| `libXres` | 1 | 1 |
| `libXv` | 1 | 1 |
| `libXvMC` | 1 | 1 |
| `libXxf86dga` | 1 | 1 |
| `libXxf86vm` | 1 | 1 |
| `libass` | 1 | 1 |
| `libconfig` | 1 | 1 |
| `libepoxy` | 3 | 2 |
| `libevdev` | 1 | 1 |
| `libfontenc` | 1 | 1 |
| `libinput` | 1 | 1 |
| `libqb` | 1 | 1 |
| `libssh` | 2 | 1 |
| `libuuid` | 2 | 1 |
| `libvirt-python` | 2 | 2 |
| `libxkbcommon` | 1 | 1 |
| `libxkbfile` | 1 | 1 |
| `libxshmfence` | 1 | 1 |
| `llvm` | 1 | 1 |
| `markupsafe` | 2 | 1 |
| `maven` | 1 | 1 |
| `mesa` | 3 | 2 |
| `mit-kerberos` | 1 | 1 |
| `mkfontscale` | 1 | 1 |
| `mom` | 1 | 1 |
| `nfs-utils` | 1 | 1 |
| `nss` | 3 | 3 |
| `openbox` | 1 | 1 |
| `openssh` | 1 | 1 |
| `otopi` | 1 | 1 |
| `ovirt-ansible-collection` | 2 | 1 |
| `ovirt-dwh` | 2 | 1 |
| `ovirt-engine` | 3 | 2 |
| `ovirt-engine-sdk-python` | 2 | 1 |
| `ovirt-hosted-engine-ha` | 2 | 1 |
| `ovirt-hosted-engine-setup` | 2 | 1 |
| `ovirt-imageio` | 2 | 1 |
| `ovirt-web-ui` | 2 | 1 |
| `pacemaker` | 1 | 1 |
| `pango` | 3 | 2 |
| `pcs` | 1 | 1 |
| `php` | 1 | 1 |
| `picom` | 1 | 1 |
| `python` | 1 | 1 |
| `python-asciidoc` | 1 | 1 |
| `python-build` | 1 | 1 |
| `python-cachecontrol` | 1 | 1 |
| `python-certifi` | 1 | 1 |
| `python-cssselect` | 1 | 1 |
| `python-cython` | 1 | 1 |
| `python-dbus` | 1 | 1 |
| `python-dbusmock` | 1 | 1 |
| `python-docutils` | 1 | 1 |
| `python-doxypypy` | 1 | 1 |
| `python-doxyqml` | 1 | 1 |
| `python-gi-docgen` | 1 | 1 |
| `python-html5lib` | 1 | 1 |
| `python-lxml` | 1 | 1 |
| `python-mako` | 1 | 1 |
| `python-numpy` | 1 | 1 |
| `python-pip` | 1 | 1 |
| `python-ply` | 1 | 1 |
| `python-psutil` | 1 | 1 |
| `python-py3c` | 1 | 1 |
| `python-pyatspi2` | 1 | 1 |
| `python-pycairo` | 1 | 1 |
| `python-pygdbmi` | 1 | 1 |
| `python-pygments` | 1 | 1 |
| `python-pygobject` | 1 | 1 |
| `python-pyparsing` | 1 | 1 |
| `python-pyserial` | 1 | 1 |
| `python-pytest` | 1 | 1 |
| `python-pyxdg` | 1 | 1 |
| `python-pyyaml` | 1 | 1 |
| `python-recommonmark` | 1 | 1 |
| `python-requests` | 2 | 2 |
| `python-scour` | 1 | 1 |
| `python-sentry-sdk` | 1 | 1 |
| `python-six` | 1 | 1 |
| `python-sphinx` | 1 | 1 |
| `python-sphinx-rtd-theme` | 1 | 1 |
| `python-urllib3` | 1 | 1 |
| `python-wheel` | 1 | 1 |
| `python3-dbus` | 1 | 1 |
| `python3-dbusmock` | 1 | 1 |
| `python3-legacy` | 1 | 1 |
| `python3-pyatspi2` | 1 | 1 |
| `python3-pycairo` | 1 | 1 |
| `python3-pygobject` | 1 | 1 |
| `pyyaml` | 2 | 1 |
| `resource-agents` | 1 | 1 |
| `rofi` | 1 | 1 |
| `rustc` | 1 | 1 |
| `shadow` | 2 | 1 |
| `shared-mime-info` | 1 | 1 |
| `startup-notification` | 1 | 1 |
| `sway` | 1 | 1 |
| `vdsm` | 3 | 2 |
| `wayland-protocols` | 1 | 1 |
| `wildfly` | 2 | 1 |
| `wlroots` | 1 | 1 |
| `x265` | 1 | 1 |
| `xauth` | 1 | 1 |
| `xcb-util` | 1 | 1 |
| `xcb-util-cursor` | 1 | 1 |
| `xcb-util-image` | 1 | 1 |
| `xcb-util-keysyms` | 1 | 1 |
| `xcb-util-renderutil` | 1 | 1 |
| `xcb-util-wm` | 1 | 1 |
| `xcb-util-xrm` | 1 | 1 |
| `xclip` | 1 | 1 |
| `xclock` | 1 | 1 |
| `xcursor-themes` | 1 | 1 |
| `xdpyinfo` | 1 | 1 |
| `xev` | 1 | 1 |
| `xf86-input-evdev` | 1 | 1 |
| `xf86-input-libinput` | 1 | 1 |
| `xf86-input-synaptics` | 1 | 1 |
| `xf86-video-amdgpu` | 1 | 1 |
| `xf86-video-ati` | 1 | 1 |
| `xf86-video-fbdev` | 1 | 1 |
| `xf86-video-intel` | 1 | 1 |
| `xf86-video-nouveau` | 1 | 1 |
| `xf86-video-vesa` | 1 | 1 |
| `xf86-video-vmware` | 1 | 1 |
| `xinit` | 1 | 1 |
| `xkbcomp` | 1 | 1 |
| `xkill` | 1 | 1 |
| `xorg-libs` | 1 | 1 |
| `xorg-server` | 1 | 1 |
| `xprop` | 1 | 1 |
| `xrandr` | 1 | 1 |
| `xrdb` | 1 | 1 |
| `xset` | 1 | 1 |
| `xsetroot` | 1 | 1 |
| `xterm` | 1 | 1 |
| `xwininfo` | 1 | 1 |

---

# MISSING — 0 packages

**None.** Every package in `pool/main/` has at least one definition in
`sources/definitions/`. Every published package is reproducible from a
definition that still exists.
