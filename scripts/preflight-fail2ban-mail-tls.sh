#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Fail2ban and TLS hardening preflight: read-only ==='
echo '[Fail2ban]'
if command -v fail2ban-client >/dev/null 2>&1; then
 fail2ban-client -V 2>&1 | head -n 2 || true
 fail2ban-client status 2>&1 | head -n 8 || true
else echo 'fail2ban_client=missing'; fi
systemctl is-enabled fail2ban 2>/dev/null || true
echo '[Journal logging]'
for unit in postfix dovecot apache2; do
 echo "$unit active=$(systemctl is-active "$unit" 2>/dev/null || true)"
 journalctl -u "$unit" --since '30 minutes ago' --no-pager -q 2>/dev/null | wc -l | awk -v u="$unit" '{print u "_journal_lines=" $1}'
done
echo '[Mail ports and TLS bindings]'
ss -lntH | awk '{print $4}' | grep -E ':(25|143|465|587|993)$' | sort -u | head -n 20
echo '[Postfix override settings]'
postconf -P 2>/dev/null | grep -E '^(smtp|submission|smtps)/inet/(smtpd_tls_security_level|smtpd_tls_auth_only|smtpd_sasl_auth_enable)' || true
echo '[Dovecot SSL and auth settings]'
doveconf -n 2>/dev/null | grep -E '^([[:space:]]*)(ssl|ssl_min_protocol|disable_plaintext_auth|auth_mechanisms)[[:space:]]*=' || true
echo '[PHP/Apache webmail check]'
php -r '$f="/var/www/html/program/include/iniset.php"; if(is_readable($f) && preg_match("/RCMAIL_VERSION.*?([0-9]+\\.[0-9]+\\.[0-9]+)/",file_get_contents($f),$m)) echo "roundcube_version=".$m[1]."\\n";' 2>/dev/null || true
echo '[Existing security jail files (paths only)]'
find /etc/fail2ban -maxdepth 2 -type f \( -name '*.local' -o -name 'jail.conf' \) -print 2>/dev/null | head -n 20
echo '[Certbot hook]'
test -x /etc/letsencrypt/renewal-hooks/deploy/90-pouge-mail-reload.sh && echo 'mail_hook_executable=yes' || echo 'mail_hook_executable=no'
echo 'Preflight complete: no service changes, no mails accessed'
