#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Fail2ban activation diagnostic (read only) ==='
echo "fail2ban_installed=$(dpkg-query -W -f='${Status}' fail2ban 2>/dev/null || true)"
echo "fail2ban_unit=$(systemctl is-active fail2ban 2>/dev/null || true)"
echo "fail2ban_enabled=$(systemctl is-enabled fail2ban 2>/dev/null || true)"
echo 'Systemd status (first 15 lines):'
systemctl status fail2ban --no-pager -l 2>&1 | head -n 15 || true
echo 'Recent fail2ban errors:'
journalctl -u fail2ban --since '20 minutes ago' -o cat --no-pager 2>/dev/null | tail -n 28 | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IPv4]/g' || true
echo "socket_present=$([ -S /run/fail2ban/fail2ban.sock ] && echo yes || echo no)"
echo 'Fail2ban test configuration:'
fail2ban-client -t 2>&1 | tail -n 8 || true
echo 'Dovecot jail status (if daemon active):'
if [ -S /run/fail2ban/fail2ban.sock ]; then timeout 8 fail2ban-client status dovecot 2>&1 | sed -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/[IPv4]/g' | head -n 18 || true; fi
echo "dovecot=$(systemctl is-active dovecot || true)"
echo "postfix=$(systemctl is-active postfix || true)"
echo 'No changes performed'
