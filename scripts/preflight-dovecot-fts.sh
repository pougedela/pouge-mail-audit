#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Dovecot FTS Xapian preflight (read-only) ==='
echo "Dovecot: $(dovecot --version)"
echo "Xapian installed: $(dpkg-query -W -f='${Status}' dovecot-fts-xapian 2>/dev/null || echo no)"
echo 'Package candidate:'
apt-cache policy dovecot-fts-xapian | head -n 9
echo 'Existing mail plugins:'
doveconf -h mail_plugins 2>/dev/null || true
echo 'Existing FTS settings (non-secret):'
doveconf -n 2>/dev/null | grep -Ei 'fts|indexer-worker|mail_plugins' | head -n 35 || true
echo 'Dovecot journal issue counts by signature (24h, no log content):'
journalctl -u dovecot --since '24 hours ago' -o cat --no-pager 2>/dev/null | grep -Ei 'error|fatal|panic|timeout' | sed -E 's/.*(Error:|Fatal:|Panic:|timeout).*/\1/I' | sort | uniq -c || true
echo 'Recent IMAP index errors:'
journalctl -u dovecot --since '24 hours ago' -o cat --no-pager 2>/dev/null | grep -Eic 'index.*(corrupt|error|failed)|(corrupt|error|failed).*index' || true
echo 'Free RAM MB:'
awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo
echo 'Free disk MB:'
df -Pm /home | awk 'NR==2{print $4}'
echo 'Mailbox resolution:'
for u in titi pouge; do
  if doveadm user "$u" >/dev/null 2>&1; then echo "dovecot_user=$u found=yes"; else echo "dovecot_user=$u found=no"; fi
done
echo 'End of read-only preflight'
