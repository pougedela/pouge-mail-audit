#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
root=/home/titi/Maildir
limit="${SCAN_LIMIT:-500}"
[[ "$limit" =~ ^[0-9]+$ ]] && ((limit>=1 && limit<=500)) || exit 2
[[ -d "$root/cur" && -d "$root/new" ]] || { echo 'Mailbox not found'; exit 2; }
command -v rspamc >/dev/null
systemctl is-active --quiet rspamd
seen=0; high=0; medium=0; low=0; failed=0
echo 'Mailbox=titi@pouge.net mode=read-only'
while IFS= read -r -d '' file; do
  bytes=$(stat -c %s -- "$file" 2>/dev/null || echo 0)
  ((bytes>0 && bytes<=5242880)) || continue
  output=$(timeout 12 rspamc -j -h 127.0.0.1:11333 symbols < "$file" 2>/dev/null) || { ((failed+=1)); ((seen+=1)); ((seen>=limit)) && break; continue; }
  score=$(printf '%s\n' "$output" | python3 -c 'import json,sys; s=sys.stdin.read(); i=s.find("{"); o=json.loads(s[i:]) if i>=0 else {}; v=o.get("score"); print(v if isinstance(v,(int,float)) else "")' 2>/dev/null || true)
  if [[ -z "$score" ]]; then ((failed+=1))
  elif awk -v s="$score" 'BEGIN {exit !(s>=15)}'; then ((high+=1))
  elif awk -v s="$score" 'BEGIN {exit !(s>=8)}'; then ((medium+=1))
  else ((low+=1))
  fi
  ((seen+=1))
  ((seen>=limit)) && break
done < <(find "$root/cur" "$root/new" -maxdepth 1 -type f -print0)
echo "scanned=$seen high_ge_15=$high review_8_to_15=$medium lower=$low failed=$failed"
echo 'No files modified, moved or deleted'
if ((seen>0 && failed==seen)); then exit 2; fi
