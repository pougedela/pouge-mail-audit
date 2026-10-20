#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'Must run as root'; exit 2; }
. /etc/os-release
[ "${VERSION_CODENAME:-}" = noble ] || exit 2
systemctl is-active --quiet dovecot
doveconf -h mail_plugins | grep -q fts_xapian
for user in pouge titi; do doveadm user "$user" >/dev/null; done
[ "$(df -Pm /home | awk 'NR==2{print $4}')" -ge 15000 ] || exit 3
echo '=== Installing recurring FTS indexing for pouge and titi ==='
install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/index-both-mailboxes.sh <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
exec 9>/run/index-both-mailboxes.lock
flock -n 9 || { echo 'Previous full-mailbox index is still active; skipping overlap'; exit 0; }
echo "started_utc=$(date -u +%FT%TZ)"
for user in pouge titi; do
  [ "$(df -Pm /home | awk 'NR==2{print $4}')" -ge 10000 ] || { echo 'Disk space low; aborting'; exit 4; }
  echo "indexing_user=$user all_current_folders=yes"
  /usr/bin/ionice -c 3 /usr/bin/nice -n 15 /usr/bin/doveadm index -u "$user" '*'
  echo "completed_user=$user"
done
echo "completed_utc=$(date -u +%FT%TZ)"
SCRIPT
chmod 0750 /usr/local/sbin/index-both-mailboxes.sh
cat > /etc/systemd/system/pouge-titi-fts-all.service <<'SERVICE'
[Unit]
Description=FTS Xapian indexing of all mail folders for pouge and titi
Wants=dovecot.service
After=dovecot.service
ConditionPathExists=/usr/bin/doveadm

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/index-both-mailboxes.sh
CPUQuota=65%
MemoryMax=1800M
IOSchedulingClass=idle
Nice=15
TimeoutStartSec=infinity
TimeoutStopSec=60
SERVICE
cat > /etc/systemd/system/pouge-titi-fts-all.timer <<'TIMER'
[Unit]
Description=Reindex all pouge and titi folders including newly created ones

[Timer]
OnCalendar=*-*-* 03,09,15,21:00:00
Persistent=true
RandomizedDelaySec=10m
Unit=pouge-titi-fts-all.service

[Install]
WantedBy=timers.target
TIMER
systemd-analyze verify /etc/systemd/system/pouge-titi-fts-all.service /etc/systemd/system/pouge-titi-fts-all.timer
systemctl daemon-reload
systemctl enable --now pouge-titi-fts-all.timer
if systemctl is-active --quiet pouge-fts-index.service; then
 echo 'Existing pouge-only job is still active; new all-folder initial run deferred to timer'
else
 systemctl start --no-block pouge-titi-fts-all.service
 echo 'initial_index=started_in_background'
fi
systemctl show pouge-titi-fts-all.timer -p ActiveState -p NextElapseUSecRealtime --no-pager
systemctl show pouge-titi-fts-all.service -p ActiveState -p SubState --no-pager
echo 'No mailbox removed or modified; all existing and future folders covered by periodic scans.'
