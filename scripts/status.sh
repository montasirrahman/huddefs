#!/bin/bash
# One-screen health and progress. Run from bf-repo.
#
# Everything here is checked against an ARTIFACT rather than a process record,
# because every silent defect in this project came from trusting the record:
# packages counted from the index, emptiness from the archives, dependency
# resolvability from what the client would actually see.
set -uo pipefail
B="${B:-bf-build}"

echo "=== machines ==="
printf '  bf-repo   %s\n' "$(df -h / | tail -1 | awk '{print $3" used of "$2" ("$5")"}')"
printf '  bf-build  %s\n' "$(ssh $B "df -h / | tail -1" | awk '{print $3" used of "$2" ("$5")"}')"
# grep -c prints 0 and exits 1 when nothing matches, so `|| echo 0` appends a
# SECOND zero and the line reads "0\n0". Take the first line and nothing else.
io_r=$(dmesg -T 2>/dev/null | grep -ciE 'i/o error|remount.*read-only' | head -1)
io_b=$(ssh $B "journalctl -k --since '30 minutes ago' --no-pager 2>/dev/null | grep -ciE 'I/O error|remount.*read-only' | head -1")
printf '  I/O errors: bf-repo %s, bf-build %s (last 30 min)\n' "$io_r" "$io_b"

echo
echo "=== builds ==="
ssh $B 'for u in redo py33 e7ten nodejs-build; do
    s=$(systemctl is-active $u 2>/dev/null || echo -)
    n=$(journalctl -u $u --no-pager -o cat 2>/dev/null | grep -c PUBLISHED | head -1)
    printf "  %-14s %-10s %s published\n" "$u" "$s" "$n"
done
echo "  currently: $(ps -eo args --no-headers | grep -oE "hud-build [^ ]+/[a-z0-9.+-]+\.huddef" | sed "s|.*/||" | head -1)"'

echo
echo "=== repositories ==="
printf '  live      %s packages, index %s  (must never change)\n' \
    "$(sqlite3 /var/www/hud-repo/packages.db 'select count(*) from packages;')" \
    "$(stat -c%y /var/www/hud-repo/packages.list | cut -d' ' -f1)"
printf '  unstable  %s packages, %s index entries\n' \
    "$(sqlite3 /var/www/hud-unstable/packages.db 'select count(*) from packages;')" \
    "$(grep -cv '^#' /var/www/hud-unstable/packages.list)"

echo
echo "=== definitions ==="
cd "$(dirname "$0")/.."
printf '  v2 converted        %s of %s\n' \
    "$(grep -l 'Source-SHA256:' huddefs/*/*.huddef | wc -l)" "$(ls huddefs | wc -l)"
printf '  empty in unstable   %s  (packages shipping nothing)\n' \
    "$(find /var/www/hud-unstable/pool/main -name '*.hud' -size -5k | wc -l)"
printf '  capability Depends  %s  (rows the client cannot resolve; must reach 0)\n' \
    "$(cut -d'|' -f7 /var/www/hud-unstable/packages.list 2>/dev/null | grep -cE '\.so\.|^exec\(|python3dist\(' | head -1)"
