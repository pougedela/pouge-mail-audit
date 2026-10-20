#!/usr/bin/env bash
set -Eeuo pipefail
. /etc/os-release
[ "${VERSION_CODENAME:-}" = jammy ] || { echo "Expected jammy"; exit 2; }
echo '=== Ubuntu 22.04 pending updates: read-only ==='
apt-get -s dist-upgrade | grep -E '^(The following|[0-9]+ upgraded|  ca-certificates|  liblzma5|  open-iscsi|  open-vm-tools|  python3-jwt|  xz-utils|Inst |Remv )' || true
echo '[Service readiness]'
for svc in postfix dovecot rspamd mysql apache2 fail2ban; do echo "$svc=$(systemctl is-active "$svc" 2>/dev/null || true)"; done
echo 'No packages installed or rebooted.'
