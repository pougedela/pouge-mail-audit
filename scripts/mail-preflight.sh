#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'Root required'; exit 1; }
command -v postconf >/dev/null
command -v doveconf >/dev/null
command -v rspamadm >/dev/null
echo 'Preflight: validating current mail delivery and spam filtering'
rspamadm configtest
systemctl is-active --quiet postfix
systemctl is-active --quiet dovecot
systemctl is-active --quiet rspamd
current=$(postconf -h smtpd_milters)
[ "$current" = 'inet:127.0.0.1:11332' ] || { echo "Unexpected active Milter: $current"; exit 1; }
timeout 5 bash -c 'echo > /dev/tcp/127.0.0.1/11332' 2>/dev/null || { echo 'Milter unavailable'; exit 1; }
# Never change final-delivery routing without mapping Postfix local/virtual recipients and Dovecot userdb.
echo 'Delivery configuration:'
for k in mydestination virtual_mailbox_domains virtual_transport home_mailbox mailbox_command; do
  printf '%s: ' "$k"
  if [ "$k" = virtual_mailbox_domains ]; then
    [ -n "$(postconf -h "$k" 2>/dev/null)" ] && echo configured || echo empty
  else
    postconf -h "$k" 2>/dev/null || true
  fi
done
printf '\nMissing MUA variables in Postfix master.cf:\n'
for k in mua_sender_restrictions mua_client_restrictions mua_helo_restrictions; do
  if grep -Eq "(^|[[:space:]])\\$\\{$k\\}" /etc/postfix/master.cf; then
    postconf -n "$k" 2>/dev/null || true
  fi
done
echo 'Not changing MUA restrictions automatically: these settings can change authentication security.'
echo 'Not changing Dovecot delivery until a complete userdb and virtual transport test is possible.'
echo 'Preflight complete. All installed components remain unchanged.'
