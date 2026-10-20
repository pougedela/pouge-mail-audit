#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Pouge FTS index status ==='
echo "utc=$(date -u +%FT%TZ)"
echo "dovecot=$(systemctl is-active dovecot || true)"
echo 'Systemd indexing unit:'
systemctl show pouge-fts-index.service -p ActiveState -p SubState -p Result -p ExecMainCode -p ExecMainStatus -p MainPID -p ActiveEnterTimestamp -p InactiveEnterTimestamp -p CPUUsageNSec --no-pager 2>/dev/null || true
echo 'Unit logs (filtered, no message content):'
journalctl -u pouge-fts-index.service --since '2 hours ago' --no-pager -o cat 2>/dev/null | grep -Ei 'started|finished|failed|timeout|terminated|stopped|killed|deactivated|exit|code' | tail -n 15 || true
echo 'Index directory sizes:'
for user in pouge titi; do
  d="/home/$user/Maildir/xapian-indexes"
  if [ -d "$d" ]; then printf '%s=' "$user"; du -sh "$d" | cut -f1; else echo "$user=absent"; fi
done
echo 'Current index processes:'
ps -eo comm,etime,%cpu,%mem | grep -E '^(doveadm|indexer-worker)[[:space:]]' || true
echo 'Resources:'
awk '/MemAvailable:/ {print "available_ram_mb="int($2/1024)}' /proc/meminfo
df -Pm /home | awk 'NR==2 {print "disk_free_mb="$4}'
echo 'No new indexing initiated or mail modified'
