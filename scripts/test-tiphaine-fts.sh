#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== FTS targeted operational test ==='
systemctl is-active --quiet dovecot
doveconf -n >/dev/null
echo 'Configured FTS settings:'
doveconf -n | grep -E '^([[:space:]]*fts[[:space:]]*=|[[:space:]]*fts_xapian[[:space:]]*=|[[:space:]]*fts_autoindex[[:space:]]*=|[[:space:]]*mail_plugins[[:space:]]*=)' || true
echo 'Tiphaine mailbox status (no email content printed):'
timeout 30 doveadm mailbox status -u titi messages INBOX | sed -E 's/[[:digit:]]{7,}/[large-number]/g'
echo 'Search smoke test:'
set +e
timeout 40 doveadm search -u titi mailbox INBOX HEADER Subject __pouge_fts_nonexistent_probe_9f41a1 >/dev/null 2>/tmp/pouge-fts-test-error
rc=$?
set -e
echo "search_exit=$rc"
if [ -s /tmp/pouge-fts-test-error ]; then
 grep -Eio 'fts|xapian|error|failed|timeout|unknown|plugin' /tmp/pouge-fts-test-error | sort -u | head -n 12 || true
fi
rm -f /tmp/pouge-fts-test-error
if [[ "$rc" -ne 0 ]]; then exit 2; fi
echo 'Test completed; mailbox contents unchanged'
