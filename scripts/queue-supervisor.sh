#!/bin/bash
# Keep the build queue moving, and say so in a file that survives a reboot.
#
# The queue has been killed three times by machine shutdowns, and each time the
# only record of where it got to was a systemd journal that does not persist.
# This writes a heartbeat to disk every ten minutes and restarts the run if the
# unit has gone away with work still queued.
#
# It restarts on ABSENCE, never on failure: a package that fails is recorded by
# the driver and skipped, so a failing package must not become a restart loop.
set -u
export PATH="/opt/hud/bin:/opt/hud/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

UNIT="${UNIT:-queue}"
RUNNER="${RUNNER:-/var/hud-build/e5/run-queue.sh}"
QUEUE="${QUEUE:-/var/hud-build/e5/queue.json}"
STATE="${STATE:-/var/hud-build/e5-state.json}"
LOG="${LOG:-/var/hud-build/e5/heartbeat.log}"
MAX_RESTARTS="${MAX_RESTARTS:-20}"

restarts=0
say() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$LOG"; }

remaining() {
    python3 - "$QUEUE" "$STATE" <<'PY'
import json, sys
q = json.load(open(sys.argv[1]))
try:
    s = json.load(open(sys.argv[2]))
except Exception:
    s = {"published": [], "failed": {}}
done = set(s["published"]) | set(s.get("failed", {}))
print(len([p for p in q if p not in done]))
PY
}

say "supervisor started; $(remaining) of $(python3 -c "import json;print(len(json.load(open('$QUEUE'))))") remaining"

while true; do
    sleep 600
    left=$(remaining)
    pub=$(python3 -c "import json;print(len(json.load(open('$STATE'))['published']))" 2>/dev/null || echo '?')
    disk=$(df -BG --output=used / | tail -1 | tr -dc '0-9')
    io=$(journalctl -k --since '10 minutes ago' --no-pager 2>/dev/null \
         | grep -ciE 'I/O error|remount.*read-only' | head -1)

    if [ "${io:-0}" -gt 0 ]; then
        say "HALT: $io I/O errors in the last 10 minutes — stopping rather than writing through a failing disk"
        systemctl stop "$UNIT" 2>/dev/null
        exit 1
    fi
    if [ "${disk:-0}" -gt 120 ]; then
        say "HALT: /var at ${disk}G, over the 120G ceiling"
        systemctl stop "$UNIT" 2>/dev/null
        exit 1
    fi

    if systemctl is-active --quiet "$UNIT"; then
        say "ok: $UNIT active, $pub published, $left queued, ${disk}G used"
        continue
    fi

    if [ "$left" -eq 0 ]; then
        say "queue drained: $pub published. supervisor exiting."
        exit 0
    fi

    restarts=$((restarts + 1))
    if [ "$restarts" -gt "$MAX_RESTARTS" ]; then
        say "HALT: restarted $MAX_RESTARTS times and $left are still queued — needs a human"
        exit 1
    fi
    say "$UNIT is gone with $left queued — restart $restarts/$MAX_RESTARTS"
    systemctl reset-failed "$UNIT" 2>/dev/null
    systemd-run --unit="$UNIT" --property=Type=simple \
        --setenv=BUILD_TIMEOUT=21600 /bin/bash "$RUNNER" >/dev/null 2>&1
done
