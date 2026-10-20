#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Install Fail2ban for Dovecot authentication ==='
[[ $(id -u) -eq 0 ]] || exit 2
systemctl is-active --quiet dovecot
if [ -e /etc/fail2ban/jail.d/90-pouge-mail.local ]; then echo 'Managed jail already exists; refusing overwrite'; exit 3; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq fail2ban
command -v fail2ban-client >/dev/null
install -d -m 755 /etc/fail2ban/jail.d
cat >/etc/fail2ban/jail.d/90-pouge-mail.local <<'CFG'
[dovecot]
enabled = true
backend = systemd
journalmatch = _SYSTEMD_UNIT=dovecot.service
port = imap,imaps,pop3,pop3s,sieve
filter = dovecot
maxretry = 6
findtime = 10m
bantime = 15m
CFG
if ! fail2ban-client -t; then
 rm -f /etc/fail2ban/jail.d/90-pouge-mail.local
 echo 'Invalid jail config removed; Fail2ban not started by this script'
 exit 4
fi
systemctl enable --now fail2ban
systemctl restart fail2ban
systemctl is-active --quiet fail2ban
fail2ban-client status dovecot
echo "dovecot_state=$(systemctl is-active dovecot)"
echo 'No changes to mail services or SSH jail; Dovecot protection enabled'
