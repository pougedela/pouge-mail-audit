#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Ubuntu 24.04 final mail migration preflight (READ-ONLY) ==='
. /etc/os-release
[ "${VERSION_CODENAME:-}" = jammy ] || { echo 'Unexpected source OS'; exit 2; }
echo "os=$PRETTY_NAME"
echo "free_root_mb=$(df -Pm / | awk 'NR==2{print $4}')"
echo 'Package database integrity:'
dpkg --audit
echo 'Remaining 22.04 upgrades:'
apt-get -s dist-upgrade | grep -E '^[0-9]+ upgraded,|^Remv ' || true
echo 'Certificate and mail service state:'
for unit in postfix dovecot rspamd mysql apache2 fail2ban certbot.timer; do echo "$unit=$(systemctl is-active "$unit" 2>/dev/null || true)"; done
echo 'Dovecot plugins and FTS config:'
dpkg-query -W -f='${binary:Package}=${Version}\n' dovecot-core dovecot-fts-xapian 2>/dev/null || true
doveconf -n 2>/dev/null | grep -E '^([[:space:]]*)(mail_plugins|fts|ssl_min_protocol|disable_plaintext_auth)[[:space:]]*=' || true
echo 'PHP, Apache and Roundcube dependencies:'
php -r 'echo "php_version=".PHP_VERSION."\n";' 2>/dev/null || true
php -m | grep -E '^(curl|dom|intl|mbstring|mysqli|pdo_mysql|xml|zip)$' || true
test -r /var/www/html/program/include/iniset.php && echo 'roundcube_webroot=present' || echo 'roundcube_webroot=missing'
echo 'Backup archives exist (metadata only):'
find /root -maxdepth 2 -type f -path '/root/ubuntu-preupgrade-*/SHA256SUMS' -printf 'backup_manifest=%h\n' 2>/dev/null | tail -n 3
echo 'Maildirs:'
for u in pouge titi; do if [ -d "/home/$u/Maildir" ]; then echo "$u=present"; else echo "$u=missing"; fi; done
echo 'Certbot focal active entries:'
grep -hEi '^[[:space:]]*deb(-src)?[[:space:]].*certbot.*focal' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null | sed -E 's#https?://[^ /]+#[redacted]#g' || true
echo 'Upgrade tool availability:'
command -v do-release-upgrade || true
echo 'No changes to packages, services, configurations, or OS.'
