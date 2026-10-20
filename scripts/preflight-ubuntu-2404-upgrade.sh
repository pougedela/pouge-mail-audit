#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Ubuntu 22.04 to 24.04 LTS migration readiness (NO UPGRADE) ==='
. /etc/os-release
echo "current_os=$PRETTY_NAME codename=${VERSION_CODENAME:-unknown}"
[ "${VERSION_CODENAME:-}" = jammy ] || { echo 'Unexpected source release; review required'; exit 2; }
echo "architecture=$(dpkg --print-architecture)"
echo "kernel=$(uname -r)"
echo "free_disk_mb=$(df -Pm / | awk 'NR==2 {print $4}')"
echo "free_ram_mb=$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)"
echo '[Release upgrade prompt and availability check]'
grep '^Prompt=' /etc/update-manager/release-upgrades 2>/dev/null || true
if command -v do-release-upgrade >/dev/null; then
 set +e
 timeout 75 do-release-upgrade -c </dev/null > /tmp/pouge-release-check.log 2>&1
 rc=$?
 set -e
 echo "release_check_exit=$rc"
 sed -n '1,15p' /tmp/pouge-release-check.log | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IPv4]/g'
 rm -f /tmp/pouge-release-check.log
else echo 'release_upgrader_missing=yes'; fi
echo '[Installed mail and webmail packages]'
for p in postfix dovecot-core dovecot-imapd dovecot-fts-xapian rspamd redis-server opendkim apache2 php php-fpm php-mysql certbot fail2ban mysql-server; do
 dpkg-query -W -f='${binary:Package}=${Version}\n' "$p" 2>/dev/null || true
done
echo '[Held packages]'
apt-mark showhold || true
echo '[Obsolete / unconfigured / half-installed packages]'
dpkg --audit || true
echo '[APT sources (redacted URLs; distribution and file only)]'
grep -RhE '^[[:space:]]*(deb |Suites:)' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | sed -E 's#https?://[^ /]+#[mirror]#g' | head -n 40 || true
echo '[Third-party package origins]'
apt-cache policy rspamd dovecot-fts-xapian roundcube 2>/dev/null | sed -E 's#https?://[^ /]+#[mirror]#g' | head -n 65 || true
echo '[APT simulation for current 22.04 packages ONLY — not release upgrade]'
apt-get -s dist-upgrade 2>&1 | tail -n 40 || true
echo '[Important local mail/webmail config exists]'
for p in /etc/postfix/main.cf /etc/postfix/master.cf /etc/dovecot/dovecot.conf /var/www/html/config/config.inc.php /etc/letsencrypt/renewal-hooks/deploy/90-pouge-mail-reload.sh; do
 [ -e "$p" ] && echo "exists=$p" || echo "missing=$p"
done
echo '[System services]'
for s in postfix dovecot rspamd apache2 mysql fail2ban certbot.timer; do echo "$s=$(systemctl is-active "$s" 2>/dev/null || true)"; done
echo '=== READINESS COMPLETE: no apt update, no source changes, no OS upgrade and no service restart ==='
