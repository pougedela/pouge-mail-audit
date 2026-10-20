#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Ubuntu 24.04 post-migration audit: READ ONLY ==='
. /etc/os-release
echo "os=$PRETTY_NAME"
[ "${VERSION_CODENAME:-}" = noble ] || { echo 'FAIL expected Ubuntu 24.04'; exit 2; }
fail=0
check_service() {
 local n="$1" state
 state=$(systemctl is-active "$n" 2>/dev/null || true)
 echo "service_$n=$state"
 [ "$state" = active ] || fail=$((fail+1))
}
for svc in apache2 mysql postfix dovecot rspamd fail2ban certbot.timer; do check_service "$svc"; done
echo '[Apache/PHP]'
if apache2ctl -t 2>&1; then echo 'apache_syntax=ok'; else echo 'apache_syntax=FAIL'; fail=$((fail+1)); fi
apache2ctl -M 2>&1 | grep -E 'php_module|proxy_fcgi_module' || true
php -r 'echo "php_version=".PHP_VERSION."\n";' || true
if find /etc/apache2/mods-enabled -maxdepth 1 -type l -name 'php*.load' -print | grep -E 'php(7\.4|8\.1)' ; then echo 'legacy_php_module_links=present'; else echo 'legacy_php_module_links=none'; fi
echo '[Web via localhost: content NOT downloaded]'
for scheme in http https; do
 code=$(curl -k -sS --max-time 10 --resolve www.pouge.net:80:127.0.0.1 --resolve www.pouge.net:443:127.0.0.1 -o /dev/null -w '%{http_code}' "$scheme://www.pouge.net/" || true)
 echo "web_${scheme}_status=$code"
 [ "$scheme" != https ] || { [ "$code" = 200 ] || fail=$((fail+1)); }
done
echo '[Roundcube and PHP extensions]'
[ -r /var/www/html/config/config.inc.php ] && echo 'roundcube_config=present' || { echo 'roundcube_config=missing'; fail=$((fail+1)); }
for ext in mbstring intl mysqli pdo_mysql dom xml curl zip; do php -m | grep -iq "^$ext$" && echo "php_$ext=ok" || { echo "php_$ext=missing"; fail=$((fail+1)); }; done
echo '[Mail config]'
postfix check 2>&1 | tail -n 8 || { echo 'postfix_check=FAIL'; fail=$((fail+1)); }
doveconf -n >/dev/null && echo 'dovecot_config=ok' || { echo 'dovecot_config=FAIL'; fail=$((fail+1)); }
echo "dovecot_fts_package=$(dpkg-query -W -f='${Version}' dovecot-fts-xapian 2>/dev/null || echo missing)"
doveconf -h mail_plugins 2>/dev/null | grep -q fts_xapian && echo 'dovecot_fts_enabled=yes' || echo 'dovecot_fts_enabled=no'
echo '[TLS certificates: metadata only]'
if command -v certbot >/dev/null; then certbot certificates 2>&1 | grep -E 'Certificate Name:|Expiry Date:|Domains:' | head -n 18 || true; fi
echo '[Fail2ban]'
timeout 10 fail2ban-client status dovecot 2>&1 | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IPv4]/g' | head -n 12 || true
echo '[Index service status]'
systemctl show pouge-fts-index.service -p ActiveState -p SubState -p Result -p MainPID --no-pager 2>/dev/null || true
echo '[Resources and package health]'
df -Pm / | awk 'NR==2 {print "disk_free_mb="$4}'
dpkg --audit
echo "failed_checks=$fail"
echo 'Audit only: no mails read, no services restarted, no configuration changed.'
[ "$fail" -eq 0 ]
