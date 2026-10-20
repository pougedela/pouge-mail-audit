#!/usr/bin/env bash
set -u
export LC_ALL=C
printf 'MAIL AUDIT (read-only) %s\n' "$(date -u +%FT%TZ)"
printf 'Host: '; hostname -f 2>/dev/null || hostname
printf '\n## OS\n'; (grep -E '^(NAME|VERSION)=' /etc/os-release || true) 2>/dev/null
printf '\n## Relevant services\n'
for s in postfix exim4 dovecot rspamd spamassassin spamd amavis clamav-daemon opendkim opendmarc fail2ban; do
  printf '%-20s ' "$s"; systemctl is-active "$s" 2>/dev/null || true
done
printf '\n## Listening mail ports (no client details)\n'
for p in 25 465 587 993 995 143 110; do
  if ss -H -ltn "( sport = :$p )" 2>/dev/null | grep -q .; then printf 'port %s listening\n' "$p"; fi
done
printf '\n## Postfix controls (selected non-secret keys)\n'
if command -v postconf >/dev/null; then
  for k in myhostname mydestination mynetworks_style smtpd_relay_restrictions smtpd_recipient_restrictions smtpd_sender_restrictions smtpd_helo_restrictions smtpd_milters non_smtpd_milters smtpd_tls_security_level smtpd_sasl_auth_enable; do
    postconf -h "$k" 2>/dev/null | sed "s/^/$k = /" || true
  done
  printf 'mynetworks configured: '; [ -n "$(postconf -h mynetworks 2>/dev/null)" ] && echo yes || echo no
fi
printf '\n## DNS TXT policies (public DNS)\n'
if command -v dig >/dev/null; then
  for name in pouge.net _dmarc.pouge.net; do
    printf '%s\n' "$name"; dig +short TXT "$name" | grep -Ei 'v=spf1|v=DMARC1' || true
  done
else echo 'dig unavailable'; fi
printf '\n## Log summary, aggregated only\n'
LOG=''
for path in /var/log/mail.log /var/log/maillog; do [ -r "$path" ] && LOG="$path" && break; done
if [ -n "$LOG" ]; then
  echo 'Note: counts cover available current log file, not strictly 24h.'
  for pattern in 'NOQUEUE: reject' 'reject:' 'status=bounced' 'status=deferred' 'status=sent' 'sasl_username=' 'blocked using' 'milter-reject'; do
    printf '%-24s %s\n' "$pattern" "$(grep -Fc "$pattern" "$LOG" 2>/dev/null || true)"
  done
else
  echo 'No readable mail log file; check journalctl locally.'
fi
printf '\n## Rspamd status\n'
if command -v rspamadm >/dev/null; then rspamadm --version 2>/dev/null | head -n 1; fi
printf '\n## Postfix queue (count only)\n'
if command -v postqueue >/dev/null; then postqueue -j 2>/dev/null | wc -l || true; fi
printf '\nEnd audit. No configuration changes performed.\n'
