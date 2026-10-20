#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Diagnose www.pouge.net after Ubuntu 24.04 upgrade (read only) ==='
. /etc/os-release
echo "os=$PRETTY_NAME"
echo '[Service states]'
for s in apache2 nginx php8.1-fpm php8.3-fpm mysql dovecot postfix; do echo "$s=$(systemctl is-active "$s" 2>/dev/null || true)"; done
echo '[Ports]'
ss -lntp 2>/dev/null | grep -E ':(80|443)[[:space:]]' || true
echo '[Apache syntax and sites]'
apache2ctl -t 2>&1 || true
apache2ctl -S 2>&1 | head -n 45 || true
echo '[Apache PHP modules]'
apache2ctl -M 2>&1 | grep -Ei 'php|proxy_fcgi|mpm_' || true
echo '[PHP]'
php -v 2>&1 | head -n 3 || true
php -m 2>/dev/null | grep -Ei 'mysqli|pdo_mysql|mbstring|intl|curl|dom|xml|zip' || true
echo '[Local HTTP(S) status — headers only]'
for proto in http https; do
 echo "checking=$proto"
 curl --silent --show-error --insecure --max-time 8 --resolve www.pouge.net:443:127.0.0.1 --resolve www.pouge.net:80:127.0.0.1 -o /dev/null -w 'status=%{http_code} redirected=%{redirect_url}\n' "$proto://www.pouge.net/" 2>&1 | sed -E 's#(https?://)[^ /]+#\1[host]#g' || true
done
echo '[Apache recent errors — sanitized selected lines]'
journalctl -u apache2 --since '45 minutes ago' --no-pager -o cat 2>/dev/null | tail -n 35 | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IPv4]/g' || true
echo '[Webroot]'
for f in /var/www/html/index.php /var/www/html/program/include/iniset.php /var/www/html/config/config.inc.php; do [ -r "$f" ] && echo "$f=present" || echo "$f=missing"; done
echo 'No changes made.'
