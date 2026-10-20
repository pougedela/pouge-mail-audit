#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Mail TLS and webmail exposure follow-up ==='
echo '[Postfix submission / smtps overrides (no secrets)]'
postconf -P 2>/dev/null | grep -E '/(smtpd_tls_security_level|smtpd_tls_auth_only|smtpd_sasl_auth_enable|smtpd_tls_mandatory_protocols|smtpd_tls_protocols|smtpd_tls_mandatory_ciphers)\s*=' || true
echo '[Postfix global TLS policy]'
for p in smtpd_tls_security_level smtpd_tls_auth_only smtpd_tls_protocols smtpd_tls_mandatory_protocols smtpd_tls_mandatory_ciphers smtpd_tls_ciphers; do echo "$p=$(postconf -h "$p" 2>/dev/null || true)"; done
echo '[Dovecot TLS policy]'
doveconf -n 2>/dev/null | grep -E '^[[:space:]]*(ssl|ssl_min_protocol|ssl_cipher_list|disable_plaintext_auth|auth_mechanisms)[[:space:]]*=' || true
echo '[Listening ports by bind scope (addresses abbreviated to local/public categories)]'
ss -lntH | awk '{print $4}' | while read -r p; do
 port="${p##*:}"
 case "$port" in 3306|33060|6379|11332|11333|11334|143|993|25|465|587|80|443)
 case "$p" in 127.*|\[::1\]*|::1:*) scope=loopback;; 0.0.0.0:*|\[::\]:*) scope=all-interfaces;; *) scope=specific-interface;; esac
 echo "port=$port scope=$scope";;
 esac
done
echo '[Apache vhost names and docroots (no passwords)]'
apache2ctl -S 2>&1 | grep -E 'namevhost|default server|port 80|port 443' | head -n 35 || true
grep -RihE '^[[:space:]]*(ServerName|ServerAlias|DocumentRoot|Alias[[:space:]]+/roundcube)' /etc/apache2/sites-enabled /etc/apache2/conf-enabled 2>/dev/null | sed -E 's/[[:space:]]+/ /g' | head -n 55 || true
echo '[Roundcube discovery]'
find /var/www /usr/share /opt -maxdepth 5 -type f \( -name rcube.php -o -name 'roundcube.js' \) -print 2>/dev/null | head -n 15
echo '[Fail2ban install state]'
dpkg-query -W -f='fail2ban_version=${Version}\n' fail2ban 2>/dev/null || true
echo '[Certbot renew dry-run not executed]'
echo 'Read-only audit finished'
