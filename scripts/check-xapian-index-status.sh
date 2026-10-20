#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Xapian index status after interrupted SSH ==='
echo "dovecot_active=$(systemctl is-active dovecot || true)"
echo 'Relevant active processes (counts only):'
for name in doveadm indexer-worker; do
 n=$(pgrep -fc "$name" || true)
 echo "$name processes=$n"
done
echo 'Index worker recent errors (counts only):'
journalctl -u dovecot --since '25 minutes ago' --no-pager -o cat 2>/dev/null | grep -Eic '(fts|xapian|indexer).*(error|fatal|failed|panic)' || true
echo 'Xapian index files (count and disk usage):'
for root in /home/titi/Maildir /home/pouge/Maildir; do
 test -d "$root" || continue
 echo "maildir=$(basename "$(dirname "$root")")"
 find "$root" -type f \( -iname '*xapian*' -o -iname '*fts*' -o -name 'termlist.*' -o -name 'postlist.*' \) -printf '.' 2>/dev/null | wc -c
 find "$root" -maxdepth 3 -type d \( -iname '*xapian*' -o -iname '*fts*' \) -print 2>/dev/null | head -n 15
done
echo 'Tiphaine Xapian index size and modification time:'
dir=/home/titi/Maildir/xapian-indexes
if [ -d "$dir" ]; then
 du -sh "$dir" 2>/dev/null || true
 find "$dir" -type f -printf '%T@ %s\n' 2>/dev/null | sort -nr | head -n 5 | awk '{printf "recent_index_file_epoch=%s size_bytes=%s\n",$1,$2}'
else
 echo 'Tiphaine index directory absent'
fi
echo 'Active indexing command signatures (no arguments or mail data):'
for pid in $(pgrep -f '^doveadm index' || true); do
  ps -p "$pid" -o pid=,etime=,stat=,comm= 2>/dev/null || true
done
echo 'Available RAM and disk:'
awk '/MemAvailable:/ {print "ram_mb="int($2/1024)}' /proc/meminfo
df -Pm /home | awk 'NR==2{print "disk_free_mb="$4}'
echo 'Read-only status complete'
