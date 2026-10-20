#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo "MAIL VALIDATION $(date -u +%FT%TZ)"
for s in postfix dovecot rspamd; do printf '%s=' "$s"; systemctl is-active "$s"; done
echo "milter=$(postconf -h smtpd_milters 2>/dev/null)"
echo "milter_default_action=$(postconf -h milter_default_action 2>/dev/null)"
echo "milter_protocol=$(postconf -h milter_protocol 2>/dev/null)"
echo "transport=$(postconf -h virtual_transport 2>/dev/null)"
echo "domains overlap: local versus virtual"
postconf -h mydestination 2>/dev/null | tr ',' '\n' | sed 's/^ *//g' | grep -Fx 'pouge.net' >/dev/null && local_domain=yes || local_domain=no
postconf -h virtual_mailbox_domains 2>/dev/null | grep -Fq 'pouge.net' && virtual_domain=yes || virtual_domain=unknown
echo "pouge.net_in_mydestination=$local_domain"
echo "pouge.net_in_virtual_mailbox_domains=$virtual_domain"
echo "maildrop transport candidates:"
postconf -M 2>/dev/null | grep -E '^(virtual|local|lmtp|dovecot)/' | cut -c 1-160 || true
echo "mailbox metadata (no message contents/addresses):"
for d in /home/titi/Maildir/new /home/titi/Maildir/cur /home/titi/Maildir/.Junk/new /home/titi/Maildir/.Junk/cur; do
  if [ -d "$d" ]; then
    echo "folder=$d count=$(find "$d" -maxdepth 1 -type f | wc -l)"
  fi
done
echo "Recent Rspamd header evidence in actual Maildir messages (no message contents logged):"
for d in /home/titi/Maildir/new /home/titi/Maildir/cur; do
 [ -d "$d" ] || continue
 find "$d" -maxdepth 1 -type f -mmin -240 -print0 |
   xargs -0 -r grep -ilE -m 1 '^(X-Spam-Status|X-Spamd-Result|X-Rspamd-Queue-Id|X-Spam-Level):' 2>/dev/null |
   wc -l | xargs echo "$d header_count="
done
echo "Postfix milter recent log totals (current log only):"
if [ -r /var/log/mail.log ]; then
  for pattern in 'milter-reject' 'milter' 'status=sent' 'status=deferred'; do
   printf '%s=%s\n' "$pattern" "$(grep -Fci "$pattern" /var/log/mail.log || true)"
  done
fi
echo "Dovecot LDA executable=$(command -v dovecot-lda || echo missing)"
echo "Dovecot Sieve compiler=$(command -v sievec || echo missing)"
echo "Validation finished; no mail sent, deleted, or moved."
