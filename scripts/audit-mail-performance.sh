#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Mail server performance audit (read-only) ==='
echo 'OS:'; . /etc/os-release; echo "$PRETTY_NAME"
echo 'Kernel:'; uname -r
echo 'Uptime and load:'; uptime
echo 'CPU:'; nproc
echo 'Memory and swap:'; free -h
echo 'Filesystem usage:'; df -hT / /home 2>/dev/null
echo 'Disk inodes:'; df -i /home
echo 'Dovecot version:'; dovecot --version 2>&1 || true
echo 'Available search packages:'; dpkg-query -W -f='${binary:Package} ${Version}\n' 'dovecot*' '*xapian*' '*solr*' 2>/dev/null | grep -Ei 'dovecot|xapian|solr' || true
echo 'Dovecot relevant configuration (secret-free selectors):'
for k in mail_location mail_home mail_plugins mail_fsync maildir_very_dirty_syncs mmap_disable mail_cache_min_mail_count mail_cache_fields mail_always_cache_fields; do
 v=$(doveconf -h "$k" 2>/dev/null || true)
 [ -z "$v" ] || printf '%s=%s\n' "$k" "$v"
done
echo 'FTS configuration keys:'
doveconf -n 2>/dev/null | grep -Ei '(^|[[:space:]])(fts|plugin|mail_location|mail_plugins|mail_index_path|mailbox_list_index|mailbox_list_index_very_dirty_syncs)[[:space:]_=]' | sed -E 's/(password|secret|key)[[:space:]]*=.*/\1=[redacted]/I' || true
echo 'IMAP service state:'; systemctl is-active dovecot postfix rspamd redis-server 2>/dev/null || true
echo 'Maildir folder metadata:'
for account in titi pouge; do
 root="/home/$account/Maildir"
 if [ -d "$root" ]; then
  echo "account=$account"
  for dir in cur new .Junk/cur .Junk/new; do
   if [ -d "$root/$dir" ]; then
    count=$(find "$root/$dir" -maxdepth 1 -type f -printf '. ' | wc -w)
    echo "folder=$dir messages=$count"
   fi
  done
  find "$root" -maxdepth 2 -type f \( -name 'dovecot.index*' -o -name 'dovecot-uidlist' \) -printf '%f %s bytes\n' | sort -u | head -n 15
 fi
done
echo 'Recent Dovecot error counts (last 24h):'
journalctl -u dovecot --since '24 hours ago' --no-pager -o cat 2>/dev/null | grep -Eic 'error|fatal|panic|timeout' || true
echo 'Audit complete; no files, configuration or messages modified.'
