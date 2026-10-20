#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[ "$(id -u)" -eq 0 ] || { echo "root required"; exit 2; }
. /etc/os-release
[ "${VERSION_CODENAME:-}" = jammy ] || exit 2
stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="/root/ubuntu-preupgrade-$stamp"
mkdir -m 700 "$out"
echo "backup_directory=$out"
paths=()
for p in /etc/postfix /etc/dovecot /etc/rspamd /etc/opendkim.conf /etc/apache2 /etc/letsencrypt /etc/fail2ban /etc/apt /etc/mysql /var/www/html/config; do
  [ ! -e "$p" ] || paths+=("$p")
done
tar -czf "$out/config.tar.gz" "${paths[@]}" 2>"$out/tar-warnings.log"
tar -tzf "$out/config.tar.gz" >/dev/null
echo "config_backup_verified=yes"
if mysql -Nse 'SELECT 1' >/dev/null 2>&1; then
  if mysqldump --all-databases --single-transaction --routines --triggers --events --hex-blob | gzip -1 >"$out/mysql.sql.gz"; then
    gzip -t "$out/mysql.sql.gz"
    echo "mysql_backup_verified=yes"
  else
    rm -f "$out/mysql.sql.gz"
    echo "mysql_backup_failed=yes"
    exit 4
  fi
else
  echo "mysql_backup_failed=authentication"
  exit 5
fi
sha256sum "$out/config.tar.gz" "$out/mysql.sql.gz" > "$out/SHA256SUMS"
echo "backup_total_mb=$(du -sm "$out" | awk '{print $1}')"
for u in pouge titi; do
  d="/home/$u/Maildir"
  if [ -d "$d" ]; then echo "maildir_${u}_size_mb=$(du -sm "$d" | awk '{print $1}')"; else echo "maildir_${u}=missing"; fi
done
echo 'No Maildir copy made: OVH snapshot must be restorable and ideally maintain an off-server Maildir backup.'
echo 'No APT sources changed; no services restarted; no OS upgrade performed.'
