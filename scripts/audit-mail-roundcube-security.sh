#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Read-only mail / Roundcube security audit ==='
. /etc/os-release
echo "os=$PRETTY_NAME"
echo "kernel=$(uname -r)"
echo '[Installed components]'
for pkg in postfix dovecot-core dovecot-imapd dovecot-fts-xapian rspamd redis-server opendkim roundcube roundcube-core nginx apache2 openssl php-fpm fail2ban certbot python3-certbot-nginx python3-certbot-apache; do
  dpkg-query -W -f='${binary:Package}=${Version}\n' "$pkg" 2>/dev/null || true
done
echo '[Pending security-related package updates from cached APT metadata]'
apt list --upgradable 2>/dev/null | grep -Ei 'postfix|dovecot|roundcube|rspamd|redis|opendkim|nginx|apache|openssl|php|fail2ban|certbot' | head -n 35 || true
echo '[Services]'
for s in postfix dovecot rspamd redis-server opendkim fail2ban nginx apache2 certbot.timer; do
  echo "$s=$(systemctl is-active "$s" 2>/dev/null || true)"
done
echo '[TCP listening ports only, no addresses]'
ss -lntH | awk '{print $4}' | sed -E 's/.*:([0-9]+)$/\1/' | sort -nu | paste -sd, -
echo '[Mail security configuration flags]'
for key in smtpd_tls_security_level smtpd_tls_auth_only smtpd_sasl_auth_enable disable_vrfy_command smtpd_tls_mandatory_protocols; do
 echo "$key=$(postconf -h "$key" 2>/dev/null || true)"
done
doveconf -n 2>/dev/null | grep -E '^[[:space:]]*(ssl[[:space:]]*=|disable_plaintext_auth|auth_mechanisms|mail_plugins)' | head -n 15 || true
echo '[Fail2ban active jails]'
fail2ban-client status 2>/dev/null | grep -E '^Status|Jail list|Number of jail' || true
echo '[Roundcube candidates]'
for d in /usr/share/roundcube /var/lib/roundcube /var/www/roundcube /var/www/html/roundcube /opt/roundcube; do
 if [ -d "$d" ]; then
   echo "roundcube_path=$d"
   find "$d" -maxdepth 2 -type f -name composer.json -print 2>/dev/null | head -n 4
 fi
done
echo '[Containers referencing webmail (names and image tags only)]'
if command -v docker >/dev/null 2>&1; then docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -Ei 'roundcube|webmail|snappymail|sogo' || true; fi
echo '[TLS certificates: expiry only]'
if command -v certbot >/dev/null 2>&1; then
 certbot certificates 2>/dev/null | grep -E 'Certificate Name:|Expiry Date:|Certificate Path:' | head -n 30 || true
fi
echo '[Renewal hook presence]'
test -e /etc/letsencrypt/renewal-hooks/deploy/90-pouge-mail-reload.sh && echo 'mail_cert_deploy_hook=installed' || echo 'mail_cert_deploy_hook=missing'
echo 'Audit complete: no changes, no active port probing'
