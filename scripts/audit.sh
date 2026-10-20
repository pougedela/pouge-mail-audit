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

printf '\n## titi mailbox (metadata only; no email bodies, subjects or sender addresses)\n'
found=0
for root in /home/titi/Maildir /home/titi/mail /var/mail/titi /var/spool/mail/titi /var/vmail/pouge.net/titi /var/vmail/pouge.net/titi/Maildir /var/mail/vhosts/pouge.net/titi /var/mail/vhosts/pouge.net/titi/Maildir; do
  [ -e "$root" ] || continue
  found=1
  if [ -f "$root" ]; then
    printf 'mbox candidate: %s; size_bytes=%s\n' "$root" "$(stat -c %s "$root" 2>/dev/null || echo unreadable)"
  elif [ -d "$root" ]; then
    printf 'mailbox candidate: %s\n' "$root"
    for folder in "$root" "$root"/.Junk "$root"/.Spam "$root"/Junk "$root"/Spam "$root"/Maildir "$root"/Maildir/.Junk "$root"/Maildir/.Spam; do
      [ -d "$folder/cur" ] || [ -d "$folder/new" ] || continue
      for state in cur new; do
        if [ -d "$folder/$state" ]; then
          count=$(find "$folder/$state" -maxdepth 1 -type f 2>/dev/null | wc -l)
          printf 'folder=%s state=%s count=%s\n' "${folder#"$root"}" "$state" "$count"
        fi
      done
    done
  fi
done
[ "$found" -eq 1 ] || echo 'No titi mailbox found in standard locations (virtual mailbox path may differ).'
if [ -n "$LOG" ]; then
  printf 'log lines mentioning recipient titi@pouge.net (current log only): '
  grep -Eic 'to=<?titi@pouge\\.net>?' "$LOG" 2>/dev/null || true
fi


printf '\n## Rspamd troubleshooting (read-only)\n'
if command -v rspamadm >/dev/null 2>&1; then
  rspamadm configtest 2>&1 | tail -n 12 || true
  echo 'Configured worker listeners (limited, no secrets):'
  rspamadm configdump worker 2>/dev/null | grep -E 'worker|bind_socket|milter|self_scan|count' | head -n 55 || true
fi
systemctl is-active rspamd redis-server 2>/dev/null || true
ss -H -ltn 2>/dev/null | awk '$4 ~ /:(11332|11333|11334)$/ {print "Listening on "$4}' || true
echo 'Rspamd recent non-sensitive service statuses:'
journalctl -u rspamd --no-pager -n 25 -o cat 2>/dev/null | grep -Ei 'error|warning|fail|cannot|bind|start|stop|worker|listen|crash' | tail -n 20 || true


printf '\n## Delivery and Sieve readiness (read-only)\n'
if command -v postconf >/dev/null 2>&1; then
 for k in mailbox_transport virtual_transport mailbox_command home_mailbox; do
  v=$(postconf -h "$k" 2>/dev/null || true)
  printf '%s=%s\n' "$k" "$v"
 done
 echo 'Postfix delivery service entries:'
 postconf -M 2>/dev/null | grep -E '^(smtp|submission|smtps|dovecot|lmtp|virtual|local)/' | cut -c1-190 | head -n 15 || true
 for k in mua_sender_restrictions mua_client_restrictions mua_helo_restrictions; do
   postconf -h "$k" >/dev/null 2>&1 && echo "$k: defined" || echo "$k: NOT DEFINED"
 done
fi
if command -v doveconf >/dev/null 2>&1; then
 echo 'Dovecot non-secret delivery options:'
 for k in mail_location protocols mail_plugins; do
  doveconf -h "$k" 2>/dev/null | sed "s/^/$k=/" || true
 done
 echo 'Sieve and LMTP package presence:'
 dpkg-query -W -f='${binary:Package}: ${Status}\n' dovecot-sieve dovecot-lmtpd dovecot-managesieved 2>/dev/null || true
 echo 'Pigeonhole tools:'
 for binary in sievec doveadm; do command -v "$binary" >/dev/null 2>&1 && echo "$binary: present" || true; done
 echo 'Sieve delivery plugin presence (configuration name only):'
 doveconf -n 2>/dev/null | grep -E '^ *(protocol (lda|lmtp)|mail_plugins|sieve(_before|_after|_dir|_global_path|_default)?) *[={]' | head -n 35 || true
fi
printf '\n## Recent mail spam metadata (no subjects or bodies)\n'
if [ -d /home/titi/Maildir ]; then
 for folder in /home/titi/Maildir/{new,cur}; do
   [ -d "$folder" ] || continue
   find "$folder" -maxdepth 1 -type f -mmin -120 -print0 2>/dev/null |
     xargs -0 -r grep -ilm 1 '^X-Spam-Status:' 2>/dev/null |
     wc -l | xargs printf 'Recent emails with X-Spam-Status in %s: %s\n' "$folder" || true
 done
fi
printf '\nEnd audit. No configuration changes performed.\n'
