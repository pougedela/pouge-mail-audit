#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Tiphaine controlled FTS index ==='
systemctl is-active --quiet dovecot
doveconf -h mail_plugins | grep -q fts_xapian
test "$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)" -ge 700 || { echo 'Insufficient available RAM'; exit 2; }
test "$(df -Pm /home | awk 'NR==2{print $4}')" -ge 3000 || { echo 'Insufficient free disk'; exit 2; }
echo 'Indexing INBOX for titi; max 8 minutes; low CPU/IO priority'
started=$(date +%s)
set +e
timeout --signal=TERM --kill-after=15s 480 nice -n 15 ionice -c 3 doveadm index -u titi INBOX >/dev/null 2>/tmp/pouge-fts-index.err
status=$?
set -e
elapsed=$(( $(date +%s) - started ))
echo "index_exit=$status duration_seconds=$elapsed"
if [ -s /tmp/pouge-fts-index.err ]; then
 grep -Eio 'error|warning|failed|timeout|xapian|fts' /tmp/pouge-fts-index.err | sort | uniq -c | head -n 10 || true
fi
rm -f /tmp/pouge-fts-index.err
echo "dovecot_active=$([[ $(systemctl is-active dovecot) == active ]] && echo yes || echo no)"
echo "available_memory_mb=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)"
echo 'No messages deleted or moved'
[[ "$status" -eq 0 ]]
