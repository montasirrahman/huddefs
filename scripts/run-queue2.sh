#!/bin/bash
# Second build driver, running beside the main queue.
#
# The main pass had already moved past cyrus-sasl, python3-distlib and
# glusterfs when their root causes were fixed, so they would otherwise wait for
# a whole second pass behind nodejs and systemd. Its own state file because
# e5.py loads state once and rewrites it whole after every package: two drivers
# sharing one file would silently lose results. Publishing is safe to overlap —
# hud-unstable takes a flock.
set -u
export HUD_BASE_ROOTFS=/var/hud-build/base-rootfs-minimal-clean.tar.zst
export PATH="/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"
export E5_STATE=/var/hud-build/e5-state-side.json
export E5_RESULTS=/var/hud-build/e5-results-side.json
python3 /var/hud-build/e5/e5.py /var/hud-build/e5/queue2.json
echo "QUEUE2DONE rc=$?"
