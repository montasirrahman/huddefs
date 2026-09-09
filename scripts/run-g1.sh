#!/bin/bash
# Launch G1 as a supervised systemd unit, on bf-build.
#
# G1 rebuilds all 253 packages in dependency order and takes many hours. The
# machines have rebooted twice mid-campaign, and both times the transient units
# and their supervisors went with them while the journal — which does not
# persist — took the only record of where the run had reached. G1 is the
# milestone; losing it to a reboot at package 200 is not acceptable.
#
# So: a named unit, plus queue-supervisor.sh watching it. The supervisor
# restarts on ABSENCE, never on failure, and g1-rebuild.sh is resumable because
# the driver skips anything already published — so a restart continues rather
# than starting over.
set -u
export PATH="/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

REPO=/root/github-repo/huddefs
STATE=/var/hud-build/g1-state.json
ORDER=/var/hud-build/g1/order.json

mkdir -p /var/hud-build/g1
[ -s "$STATE" ] || echo '{"published": [], "failed": {}}' > "$STATE"

# The supervisor counts remaining work from a flat JSON list, which is what
# g1-rebuild.sh writes to batch.json. Generate the order now so the supervisor
# has something to count before the run has produced it.
cd "$REPO"
python3 scripts/build-order.py "$ORDER" >/dev/null
python3 -c "
import json
json.dump(json.load(open('$ORDER'))['order'], open('/var/hud-build/g1/batch.json','w'))
"

systemctl reset-failed g1 2>/dev/null
systemd-run --unit=g1 --property=Type=simple \
    --setenv=BUILD_TIMEOUT=21600 \
    /bin/bash "$REPO/scripts/g1-rebuild.sh" >/dev/null 2>&1

UNIT=g1 \
RUNNER="$REPO/scripts/g1-rebuild.sh" \
QUEUE=/var/hud-build/g1/batch.json \
STATE="$STATE" \
LOG=/var/hud-build/e5/heartbeat-g1.log \
MAX_RESTARTS=40 \
setsid nohup /bin/bash "$REPO/scripts/queue-supervisor.sh" >/dev/null 2>&1 &

sleep 3
echo "g1 unit    : $(systemctl is-active g1)"
echo "supervisor : $(pgrep -cf 'queue-supervisor.sh') running"
echo "state      : $STATE"
echo "log        : /var/hud-build/g1/g1.log"
echo "heartbeat  : /var/hud-build/e5/heartbeat-g1.log"
