#!/usr/bin/env bash
set -euo pipefail
testmsg=$(mktemp)
trap 'rm -f "$testmsg"' EXIT
printf 'From: test@example.org\nTo: test@example.net\nSubject: Synthetic test\nDate: Tue, 20 Oct 2026 16:00:00 +0200\nMessage-ID: <synthetic-test@example.org>\n\nThis is a synthetic diagnostic message.\n' > "$testmsg"
echo 'Synthetic Rspamd test: no mailbox accessed'
for address in 127.0.0.1:11333 localhost:11333; do
  echo "server=$address"
  if timeout 12 rspamc -h "$address" -j symbols "$testmsg" > /tmp/pouge-rspam-test-output 2>/dev/null; then
    python3 - <<'PY'
import json
try:
 with open('/tmp/pouge-rspam-test-output') as f: d=json.load(f)
 print("JSON parse: OK; score numeric:",isinstance(d.get('score'),(float,int)))
except Exception as e:
 print("JSON parse: failed",type(e).__name__)
PY
  else
    echo 'Scanner connection or invocation failed'
  fi
done
rm -f /tmp/pouge-rspam-test-output
