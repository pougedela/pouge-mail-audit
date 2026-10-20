#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Xapian search hang diagnostic (read-only) ==='
echo "dovecot_state=$(systemctl is-active dovecot || true)"
echo "indexer_worker_count=$(pgrep -xc indexer-worker || true)"
echo "doveadm_count=$(pgrep -xc doveadm || true)"
echo 'Process resource usage (no mailbox contents):'
ps -eo comm,stat,etime,%cpu,%mem --sort=-%cpu | grep -E '^(doveadm|indexer-worker|imap|dovecot) ' | head -n 12 || true
echo 'Xapian disk usage:'
du -sh /home/titi/Maildir/xapian-indexes 2>/dev/null || true
echo 'Recent index and FTS failure counts:'
journalctl -u dovecot --since '45 minutes ago' -o cat --no-pager 2>/dev/null | grep -Eic '(xapian|fts|indexer).*(error|failed|timeout|fatal|corrupt|lock)' || true
echo 'Active FTS plugin:'
doveconf -n | grep -E '^mail_plugins =|^  fts =|^  fts_autoindex =|^  fts_xapian =' || true
echo 'Free resources:'
awk '/MemAvailable:/ {print "available_ram_mb="int($2/1024)}' /proc/meminfo
df -Pm /home | awk 'NR==2{print "free_disk_mb="$4}'
echo 'No search or indexing started, no configuration modified'
