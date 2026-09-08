#!/bin/bash
# E5/E6 runner. systemd gives services a PATH without /opt/hud/bin, and git,
# python3 tooling and hud-build all depend on it — that omission silently ate a
# whole batch of E4 commits, so it is set here rather than assumed.
set -u
export HUD_BASE_ROOTFS=/var/hud-build/base-rootfs-minimal-clean.tar.zst
export PATH="/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export GIT_AUTHOR_NAME=montasirrahman GIT_COMMITTER_NAME=montasirrahman
export GIT_AUTHOR_EMAIL=montasirrahmanbd@gmail.com GIT_COMMITTER_EMAIL=montasirrahmanbd@gmail.com

python3 /var/hud-build/e5/e5.py /var/hud-build/e5/queue.json
rc=$?

cd /root/github-repo/huddefs
if ! command -v git >/dev/null; then
    echo "FATAL: git not on PATH — refusing to continue and lose commits" >&2
    exit 30
fi
git add -A huddefs/
if ! git diff --cached --quiet; then
    git commit -q -m "E5/E6: stage the payload for the empty python3-* packages

Their [install] ran pip without --prefix/--root, so the payload went into the
build container's own Python and the .hud held metadata only. Each definition
now installs into \$DESTDIR, declares python-setuptools (the build root's
/opt/hud copy is gutted and cannot provide setuptools.build_meta), and drops the
[prerm] pip3 uninstall and [postrm] that v2 does not support.

Built and install-tested one at a time against the minimal rootfs, asserted to
contain real files rather than metadata alone, and published to the unstable
repository so the next package in the order can resolve it.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
    echo "COMMITTED $(git rev-parse --short HEAD)"
fi
echo "E5DONE rc=$rc"
