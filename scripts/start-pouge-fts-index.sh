#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Launch bounded Xapian indexing for pouge ==='
systemctl is-active --quiet dovecot
doveconf -h mail_plugins | grep -q fts_xapian
doveadm user pouge >/dev/null
[ "$(awk '/MemAvailable:/ {print int($2/1024)}' /proc/meminfo)" -ge 1000 ] || { echo 'Not enough available RAM'; exit 2; }
[ "$(df -Pm /home | awk 'NR==2 {print $4}')" -ge 15000 ] || { echo 'Not enough free disk'; exit 2; }
if pgrep -f '^doveadm (search|index) ' >/dev/null; then echo 'Another search/index is active; abort'; exit 3; fi
if systemctl is-active --quiet pouge-fts-index.service; then echo 'Indexing unit already running'; exit 3; fi
if [ -d /home/pouge/Maildir/xapian-indexes ]; then echo 'Existing pouge index detected; will not remove it'; fi
systemd-run --unit=pouge-fts-index --collect \
  --property=CPUQuota=65% \
  --property=MemoryMax=1200M \
  --property=RuntimeMaxSec=900 \
  --property=TimeoutStopSec=20 \
  /usr/bin/ionice -c 3 /usr/bin/nice -n 15 /usr/bin/timeout --signal=TERM --kill-after=15s 840 /usr/bin/doveadm index -u pouge INBOX
echo 'Indexing launched in VPS systemd unit, independent of SSH.'
systemctl show pouge-fts-index.service -p ActiveState -p MainPID -p RuntimeMaxUSec --no-pager || true
echo 'No message deleted or moved. No restart performed.'
