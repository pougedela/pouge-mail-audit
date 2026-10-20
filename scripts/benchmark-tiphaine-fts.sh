#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
echo '=== Tiphaine full-text search benchmark ==='
systemctl is-active --quiet dovecot
doveconf -h mail_plugins | grep -q fts_xapian
echo 'Mailbox count:'
doveadm mailbox status -u titi messages INBOX
echo 'Full-text search benchmark (synthetic term, no results printed):'
start=$(date +%s)
set +e
timeout 90 doveadm search -u titi mailbox INBOX TEXT __pouge_fts_probe_9f71e2b48a__ >/dev/null 2>/tmp/pouge-fts-benchmark.err
rc=$?
set -e
elapsed=$(( $(date +%s) - start ))
echo "search_exit=$rc elapsed_seconds=$elapsed"
if [[ -s /tmp/pouge-fts-benchmark.err ]]; then
 echo 'Error signatures (no message data):'
 grep -Eio 'fts|xapian|error|fail|timeout|warning' /tmp/pouge-fts-benchmark.err | sort | uniq -c || true
fi
rm -f /tmp/pouge-fts-benchmark.err
echo 'Recent FTS failures count:'
journalctl -u dovecot --since '10 minutes ago' -o cat --no-pager 2>/dev/null | grep -Eic '(fts|xapian).*(error|failed|panic)' || true
echo 'No messages modified'
[[ "$rc" -eq 0 ]]
