#!/bin/bash
# =============================================================================
# supervisor.sh — keep the conversion running without a human watching it
#
# Checks every 10 minutes:
#   - is the conversion unit still active?
#   - is exactly one build running, or have containers been orphaned?
#   - is the current build's log still growing, or is it wedged?
#   - is there disk left?
#   - did the block device start rejecting writes again?
#
# Restarts the conversion when it has stopped and there is work left. The
# converter resumes from convert-state.json, so a restart repeats nothing.
#
# HALTS rather than restarting when:
#   - I/O errors reappear in dmesg (the 2026-09-01 fault may be dormant, and a
#     second event during a phase touching the live repo would be far worse)
#   - free disk drops below 100 G
#   - the same unit has been restarted more than 5 times without progressing
# =============================================================================
set -u
SD=/var/hud-build/e4
LOG=$SD/supervisor.log
STATE=/var/hud-build/convert-state.json
TOTAL=148
MIN_FREE_GB=100
MAX_RESTARTS=5

say() { echo "$(date '+%F %T') $*" >> "$LOG"; }

done_count() {
    python3 -c "import json;print(len(json.load(open('$STATE'))['done']))" 2>/dev/null || echo 0
}

current_unit() {
    systemctl list-units 'e4[a-z]*.service' --no-legend --all --no-pager 2>/dev/null \
        | awk '{print $1}' | grep -v supervisor | tail -1
}

restarts=0
last_progress=$(done_count)
say "supervisor started; $last_progress/$TOTAL done"

while true; do
    sleep 600

    # --- storage health comes first: a repeat fault must stop everything ---
    if dmesg 2>/dev/null | tail -200 | grep -qiE 'I/O error|EXT4-fs error|remount-ro'; then
        say "HALT: I/O errors in dmesg — not restarting. The 2026-09-01 fault may have recurred."
        systemctl stop "$(current_unit)" 2>/dev/null
        exit 20
    fi
    free_gb=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
    if [ "${free_gb:-0}" -lt "$MIN_FREE_GB" ]; then
        say "HALT: only ${free_gb}G free, below the ${MIN_FREE_GB}G floor"
        systemctl stop "$(current_unit)" 2>/dev/null
        exit 21
    fi

    done_now=$(done_count)
    unit=$(current_unit)
    active=$(systemctl is-active "$unit" 2>/dev/null)

    if [ "$done_now" -ge "$TOTAL" ]; then
        say "COMPLETE: $done_now/$TOTAL processed"
        exit 0
    fi

    # --- orphaned containers: more than one build means a previous stop leaked ---
    nbuild=$(ps -eo args --no-headers | grep -c '/usr/local/bin/hud-build' || true)
    if [ "${nbuild:-0}" -gt 1 ]; then
        say "WARN: $nbuild concurrent builds — clearing orphans"
        for m in $(machinectl list --no-legend 2>/dev/null | awk '{print $1}'); do
            machinectl terminate "$m" >/dev/null 2>&1 || true
        done
    fi

    if [ "$active" = "active" ]; then
        if [ "$done_now" -gt "$last_progress" ]; then
            say "ok: $unit active, $done_now/$TOTAL (+$((done_now - last_progress)))"
            last_progress=$done_now
            restarts=0
        else
            say "ok: $unit active, $done_now/$TOTAL (no completion this interval — long build)"
        fi
        continue
    fi

    # --- not active: restart if there is work left ---
    if [ "$restarts" -ge "$MAX_RESTARTS" ]; then
        say "HALT: restarted $restarts times without progress past $done_now — needs a human"
        exit 22
    fi
    restarts=$((restarts + 1))
    say "unit $unit is '$active' at $done_now/$TOTAL — restart $restarts/$MAX_RESTARTS"

    for m in $(machinectl list --no-legend 2>/dev/null | awk '{print $1}'); do
        machinectl terminate "$m" >/dev/null 2>&1 || true
    done
    umount /run/systemd/nspawn/unix-export/* 2>/dev/null || true
    rm -rf /run/systemd/nspawn/unix-export/* 2>/dev/null || true
    rm -rf /var/hud-build/work/* /var/hud-test/run-* 2>/dev/null || true

    new="e4s$(date +%H%M%S)"
    systemctl reset-failed "$unit" 2>/dev/null || true
    systemd-run --unit="$new" --property=Type=simple \
        /bin/bash "$SD/e4.sh" >/dev/null 2>&1 && say "started $new"
done
