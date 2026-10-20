#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" = 0 ] || { echo "root required"; exit 1; }
command -v postconf >/dev/null
command -v postfix >/dev/null
systemctl is-active --quiet postfix
systemctl is-active --quiet rspamd
[ "$(postconf -h smtpd_milters 2>/dev/null)" = "inet:127.0.0.1:11332" ] || { echo "Milter mismatch: abort"; exit 1; }
timeout 3 bash -c 'echo > /dev/tcp/127.0.0.1/11332' 2>/dev/null || { echo "Milter unavailable"; exit 1; }
backup="/root/pouge-mail-safe-fix-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "$backup"
cp -a /etc/postfix/main.cf /etc/postfix/master.cf "$backup/"
echo "Backup saved: $backup"
rollback() {
  cp -a "$backup/main.cf" /etc/postfix/main.cf
  cp -a "$backup/master.cf" /etc/postfix/master.cf
  postfix check || true
  systemctl reload postfix || true
  echo "Rollback attempted from $backup"
}
trap rollback ERR
# These names are only macros used by master.cf. Empty was already their
# effective value when undefined; defining them avoids warnings and makes
# no policy change. Do NOT modify delivery transports or spam classification.
for key in mua_sender_restrictions mua_client_restrictions mua_helo_restrictions; do
  if ! postconf -n "$key" 2>/dev/null | grep -q "^$key[[:space:]]*="; then
    postconf -e "$key ="
    echo "Defined previously missing macro $key as empty (same effective value)"
  else
    echo "Preserved existing macro $key"
  fi
done
postfix check
systemctl reload postfix
trap - ERR
echo "Safe Postfix macro cleanup done. Delivery, authentication and Sieve untouched."
