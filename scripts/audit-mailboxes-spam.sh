#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo "Two-mailbox anti-spam preflight (read-only)"
echo "Rspamd: $(systemctl is-active rspamd)"
echo "Postfix: $(systemctl is-active postfix)"
echo "Milter: $(postconf -h smtpd_milters 2>/dev/null)"
echo "Delivery transport: $(postconf -h virtual_transport 2>/dev/null)"
echo "No messages are read in full, modified, or moved."
for account in titi pouge; do
  echo
  echo "Mailbox: $account@pouge.net"
  if id "$account" >/dev/null 2>&1; then
    echo "System user: present"
    home=$(getent passwd "$account" | cut -d: -f6)
    echo "Home directory detected: $([ -d "$home" ] && echo yes || echo no)"
  else
    echo "System user: not found"
  fi
  candidate="/home/$account/Maildir"
  if [ -d "$candidate/cur" ] && [ -d "$candidate/new" ]; then
    echo "Maildir exists: yes"
    for name in cur new; do
      printf '%s count=' "$name"
      find "$candidate/$name" -maxdepth 1 -type f 2>/dev/null | wc -l
    done
    if [ -d "$candidate/.Junk" ]; then echo "Junk Maildir exists: yes"; else echo "Junk Maildir exists: no"; fi
    echo "Maildir permissions:"
    stat -c '%U:%G %a %n' "$candidate" "$candidate/cur" "$candidate/new"
  else
    echo "Maildir at expected path: not confirmed"
  fi
  echo "Dovecot user lookup:"
  if doveadm user "$account@pouge.net" >/dev/null 2>&1; then
    echo "Dovecot userdb: address lookup succeeded"
  elif doveadm user "$account" >/dev/null 2>&1; then
    echo "Dovecot userdb: short username lookup succeeded"
  else
    echo "Dovecot userdb: no matching lookup (manual configuration required)"
  fi
done
echo
echo "Spam headers configured:"
rspamadm configdump milter_headers 2>/dev/null | grep -Ei 'x-spam-status|x-spamd-bar|x-spam-level|use = ' | head -n 15 || true
echo "End preflight. No changes made."
