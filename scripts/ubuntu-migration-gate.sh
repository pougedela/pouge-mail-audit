#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Ubuntu 24.04 migration gate: no changes ==='
. /etc/os-release
echo "os=$PRETTY_NAME"
echo "available_disk_mb=$(df -Pm / | awk 'NR==2{print $4}')"
echo "maildir_titi=$([ -d /home/titi/Maildir ] && echo present || echo missing)"
echo "maildir_pouge=$([ -d /home/pouge/Maildir ] && echo present || echo missing)"
echo 'Backup tool availability:'
for cmd in tar rsync mysqldump gzip sha256sum; do command -v "$cmd" >/dev/null && echo "$cmd=yes" || echo "$cmd=no"; done
echo 'Obsolete repository files (names only):'
grep -rlE 'certbot/certbot|focal' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
echo 'Package upgrade readiness:'
dpkg --audit
apt-mark showhold
echo 'Mail service states:'
for svc in postfix dovecot mysql apache2 rspamd; do echo "$svc=$(systemctl is-active "$svc" 2>/dev/null || true)"; done
echo 'This stage made zero changes to production.'
