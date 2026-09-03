#!/bin/bash
# =============================================================================
# supervisor.sh — keep the conversion running without a human watching it
#
# Checks every 10 minutes and restarts the conversion when it has stopped with
# work remaining. The converter resumes from convert-state.json, so a restart
# repeats nothing.
#
# -----------------------------------------------------------------------------
# WHY THE DISK CHECK MEASURES USED SPACE, NOT FREE SPACE
# -----------------------------------------------------------------------------
# NOTE (2026-09-03): this gate was built on a wrong diagnosis. The real cause of
# the three I/O failures was that bf-repo's VDI sits on a USB-attached external
# disk whose link drops under sustained heavy write load. Capacity was never the
# constraint — F: had 332 GB free when the third failure happened.
#
# The ceiling is kept because it is harmless and still catches runaway growth,
# but it does NOT protect against the actual failure mode, which is sustained
# write RATE over time rather than disk fullness. The I/O-error check above is
# the one that matters.
#
# Building has moved to bf-build (internal NVMe). Nothing should be building on
# bf-repo at all.
#
# =============================================================================
set -u
SD=/var/hud-build/e4
LOG=$SD/supervisor.log
STATE=/var/hud-build/convert-state.json
TOTAL=148
MAX_USED_GB=120          # halt if /var exceeds this; host headroom is ~332 GB
MAX_RESTARTS=5

say() { echo "$(date '+%F %T') $*" >> "$LOG"; }

done_count() {
    python3 -c "import json;print(len(json.load(open('$STATE'))['done']))" 2>/dev/null || echo 0
}

# df's Used column is accurate — it is Available that lies, because the guest
# cannot see that the VDI's backing store is smaller than its declared capacity.
# Using df rather than `du -s /var` also matters for cost: du walks 57 GB of
# files on a 30 MB/s disk every cycle, competing with the build it is watching.
used_gb() { df -BG --output=used / 2>/dev/null | tail -1 | tr -dc '0-9'; }

current_unit() {
    systemctl list-units 'e4[a-z0-9]*.service' --no-legend --all --no-pager 2>/dev/null \
        | awk '{print $1}' | grep -v supervisor | tail -1
}

restarts=0
last_progress=$(done_count)
say "supervisor started; $last_progress/$TOTAL done, /var at $(used_gb)G used"

while true; do
    sleep 600

    # --- storage health, in a 15 minute window ---------------------------------
    # Previously this grepped the whole dmesg ring buffer, so it matched the
    # failures from the day before and halted on stale history. The halt is
    # right; only the window was wrong.
    if journalctl -k --since "15 minutes ago" --no-pager 2>/dev/null \
        | grep -qiE 'I/O error|Buffer I/O|remount.*read-only'; then
        say "HALT: fresh I/O errors in the last 15 minutes — not restarting."
        systemctl stop "$(current_unit)" 2>/dev/null
        exit 20
    fi

    used=$(used_gb)
    if [ "${used:-0}" -gt "$MAX_USED_GB" ]; then
        say "HALT: /var at ${used}G used, over the ${MAX_USED_GB}G ceiling."
        say "      The VDI never shrinks; deleting files inside the guest does"
        say "      not return space to the host. Needs host-side attention."
        systemctl stop "$(current_unit)" 2>/dev/null
        exit 21
    fi

    done_now=$(done_count)
    unit=$(current_unit)
    active=$(systemctl is-active "$unit" 2>/dev/null)

    if [ "$done_now" -ge "$TOTAL" ]; then
        say "COMPLETE: $done_now/$TOTAL processed, /var at ${used}G used"
        exit 0
    fi

    # Bracket trick: without it the grep matches its own command line, so a
    # single build counted as two. The supervisor then ran machinectl terminate
    # on every registered machine — including the container of the build that was
    # running at the time. A watchdog that kills the thing it is watching is
    # worse than no watchdog.
    nbuild=$(ps -eo args --no-headers | grep -c '[/]usr/local/bin/hud-build' || true)
    # Only intervene when the conversion is NOT running. While it is active, a
    # second build means orphans, but terminating machines blind would take the
    # live one with it. Report it and let the per-package cleanup handle it.
    if [ "${nbuild:-0}" -gt 1 ]; then
        say "WARN: $nbuild concurrent builds detected (expected 1)"
    fi

    if [ "$active" = "active" ]; then
        if [ "$done_now" -gt "$last_progress" ]; then
            say "ok: $unit active, $done_now/$TOTAL (+$((done_now - last_progress))), /var ${used}G used"
            last_progress=$done_now
            restarts=0
        else
            say "ok: $unit active, $done_now/$TOTAL (no completion this interval), /var ${used}G used"
        fi
        continue
    fi

    if [ "$restarts" -ge "$MAX_RESTARTS" ]; then
        say "HALT: restarted $restarts times without progress past $done_now — needs a human"
        exit 22
    fi
    restarts=$((restarts + 1))
    say "unit $unit is '$active' at $done_now/$TOTAL, /var ${used}G — restart $restarts/$MAX_RESTARTS"

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
