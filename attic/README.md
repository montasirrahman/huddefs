# attic/

**176 package definitions that were never published.** Preserved exactly as
found, not consolidated and not cleaned.

## Why these are separate

Every definition here names a package that has **no entry in
`/var/www/hud-repo/pool/`**. Nothing was ever built and shipped from them, which
means two things:

1. **There is no tiebreaker.** For the packages in `huddefs/`, the copy archived
   in `pool/main/<letter>/<name>/` is the definition that actually built the
   shipped `.hud`, so it settles any disagreement. Nothing here has that. Where
   several copies of an attic definition disagree, no evidence on disk says
   which one is right.
2. **They are unverified.** A definition that has never completed a build may
   never have worked at all. Treat them as drafts.

Consolidating them would mean guessing, and a wrong guess is invisible until a
build produces something subtly incorrect. So they are left alone.

## Layout

Each package keeps its original path under `sources/definitions/`, including the
dated directory names, because that path is the only provenance these files have:

```
attic/<package>/<original path under sources/definitions>/<file>.huddef
```

176 packages, 219 files.

## What to do with them

Nothing, for now. `docs/WORKFLOW.md` step 4 is about getting the 245 shipped
packages rebuilding cleanly; these are not part of that. When one is genuinely
needed, promote it deliberately: pick a variant, convert it to v2 per
`docs/huddef-v2-spec.md`, build it, and move it into `huddefs/`.

## Contents

| Package | Files | Distinct contents |
|---|---|---|
| `adwaita-icon-theme` | 1 | 1 |
| `ansible` | 2 | 1 |
| `apache` | 2 | 1 |
| `at-spi2-core` | 1 | 1 |
| `atk` | 1 | 1 |
| `cairo` | 3 | 2 **← disagree** |
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
| `gdk-pixbuf` | 3 | 2 **← disagree** |
| `ghostscript` | 1 | 1 |
| `glib2` | 3 | 2 **← disagree** |
| `graphite2` | 1 | 1 |
| `gst-plugins-base` | 1 | 1 |
| `gtk3` | 3 | 2 **← disagree** |
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
| `libepoxy` | 3 | 2 **← disagree** |
| `libevdev` | 1 | 1 |
| `libfontenc` | 1 | 1 |
| `libinput` | 1 | 1 |
| `libqb` | 1 | 1 |
| `libssh` | 2 | 1 |
| `libuuid` | 2 | 1 |
| `libvirt-python` | 2 | 2 **← disagree** |
| `libxkbcommon` | 1 | 1 |
| `libxkbfile` | 1 | 1 |
| `libxshmfence` | 1 | 1 |
| `llvm` | 1 | 1 |
| `markupsafe` | 2 | 1 |
| `maven` | 1 | 1 |
| `mesa` | 3 | 2 **← disagree** |
| `mit-kerberos` | 1 | 1 |
| `mkfontscale` | 1 | 1 |
| `mom` | 1 | 1 |
| `nfs-utils` | 1 | 1 |
| `nss` | 3 | 3 **← disagree** |
| `openbox` | 1 | 1 |
| `openssh` | 1 | 1 |
| `otopi` | 1 | 1 |
| `ovirt-ansible-collection` | 2 | 1 |
| `ovirt-dwh` | 2 | 1 |
| `ovirt-engine` | 3 | 2 **← disagree** |
| `ovirt-engine-sdk-python` | 2 | 1 |
| `ovirt-hosted-engine-ha` | 2 | 1 |
| `ovirt-hosted-engine-setup` | 2 | 1 |
| `ovirt-imageio` | 2 | 1 |
| `ovirt-web-ui` | 2 | 1 |
| `pacemaker` | 1 | 1 |
| `pango` | 3 | 2 **← disagree** |
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
| `python-requests` | 2 | 2 **← disagree** |
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
| `vdsm` | 3 | 2 **← disagree** |
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
