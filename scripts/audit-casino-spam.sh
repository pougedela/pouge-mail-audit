#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
root=/home/titi/Maildir
[[ -d "$root/cur" && -d "$root/new" ]] || exit 2
since=$(date -d '7 days ago' +%s)
checked=0; recent=0; matches=0; low=0; mid=0; high=0; failed=0
echo 'Casino-themed mail diagnostic: last 7 days, subject and text content, no message content logged'
while IFS= read -r -d '' file; do
  ((checked>=1000)) && break
  ((checked+=1))
  # Use internal Date header and Subject; do not print either.
  if ! python3 - "$file" "$since" <<'PY'
import sys,email,email.policy,email.utils
try:
 with open(sys.argv[1],'rb') as f: m=email.message_from_binary_file(f,policy=email.policy.default,headersonly=True)
 dt=email.utils.parsedate_to_datetime(str(m.get('Date','')))
 if dt is None or dt.tzinfo is None or dt.timestamp()<int(sys.argv[2]): sys.exit(1)
 sys.exit(0)
except Exception: sys.exit(1)
PY
  then continue; fi
  ((recent+=1))
  if ! python3 - "$file" <<'PY'
import sys,email,email.policy
terms=('casino','jackpot','roulette','machine à sous','machines à sous','bonus de bienvenue','free spins','slot')
try:
 with open(sys.argv[1],'rb') as f:
  m=email.message_from_binary_file(f,policy=email.policy.default)
 parts=[m] if not m.is_multipart() else list(m.walk())
 sample=str(m.get('Subject','')).casefold()
 for p in parts:
  if p.get_content_type() in ('text/plain','text/html'):
   sample+=' '+str(p.get_content())[:150000].casefold()
 printout=any(t in sample for t in terms)
 sys.exit(0 if printout else 1)
except Exception: sys.exit(1)
PY
  then continue; fi
  ((matches+=1))
  result=$(timeout 12 rspamc -j -h 127.0.0.1:11333 symbols < "$file" 2>/dev/null) || { ((failed+=1)); continue; }
  score=$(printf '%s\n' "$result" | python3 -c 'import sys,json; s=sys.stdin.read(); i=s.find("{"); o=json.loads(s[i:]) if i>=0 else {}; v=o.get("score"); print(v if isinstance(v,(float,int)) else "")' 2>/dev/null || true)
  if [[ -z "$score" ]]; then ((failed+=1))
  elif awk -v s="$score" 'BEGIN{exit !(s>=15)}'; then ((high+=1))
  elif awk -v s="$score" 'BEGIN{exit !(s>=8)}'; then ((mid+=1))
  else ((low+=1)); fi
done < <(find "$root/cur" "$root/new" -maxdepth 1 -type f -printf '%T@ %p\0' | sort -z -nr | cut -z -d' ' -f2-)
echo "files_checked=$checked received_last_7_days=$recent casino_related=$matches score_below_8=$low score_8_to_15=$mid score_ge_15=$high scan_errors=$failed"
echo 'No messages modified or moved'
