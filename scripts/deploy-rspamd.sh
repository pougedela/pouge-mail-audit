#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Root privileges required"; exit 1; }
command -v postconf >/dev/null || { echo "Postfix not installed"; exit 1; }
command -v postfix >/dev/null || exit 1
[ -f /etc/os-release ] && grep -q '^ID=ubuntu' /etc/os-release || { echo "Unsupported distribution"; exit 1; }
if [ -n "$(postconf -h smtpd_milters)" ]; then
  echo "Existing SMTP milters detected: stop for manual review"; exit 1
fi
if grep -Eq '^ *-o +(smtpd_milters|non_smtpd_milters)=' /etc/postfix/master.cf; then
  echo "Milter overrides found: manual review required"; exit 1
fi
backup="/root/pouge-rspamd-backup-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "$backup"
cp -a /etc/postfix "$backup/postfix"
[ ! -d /etc/rspamd ] || cp -a /etc/rspamd "$backup/rspamd"
echo "Backup directory: $backup"
apt-get update -qq
apt-get install -y rspamd
install -d -m 755 /etc/rspamd/local.d
cat > /etc/rspamd/local.d/actions.conf <<'CFG'
reject = 1000;
add_header = 6;
greylist = 1000;
CFG
cat > /etc/rspamd/local.d/milter_headers.conf <<'CFG'
use = ["x-spamd-bar", "x-spam-level", "x-spam-status"];
CFG
rspamadm configtest
systemctl enable --now rspamd
if ! timeout 5 bash -c 'echo > /dev/tcp/127.0.0.1/11332' 2>/dev/null; then
  echo "Rspamd proxy milter not available. Postfix unchanged."; exit 1
fi
postconf -e 'smtpd_milters = inet:127.0.0.1:11332'
postconf -e 'milter_default_action = accept'
postfix check
systemctl reload postfix
echo "Rspamd enabled in observation mode; existing mailbox contents untouched."
