#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
root=/home/titi/Maildir
limit="${SCAN_LIMIT:-100}"
[[ "$limit" =~ ^[0-9]+$ ]] && ((limit >= 1 && limit <= 100)) || exit 2
[[ -d "$root/cur" && -d "$root/new" ]] || exit 2
[[ -d "$root/.Junk/cur" && -d "$root/.Junk/new" && -d "$root/.Junk/tmp" ]] || { echo 'Junk Maildir not configured; stop without changes'; exit 2; }
scanned=0; moved=0; failed=0
echo 'Tiphaine: move messages scoring at least 8 to existing Junk Maildir'
while IFS= read -r -d '' file; do
  bytes=$(stat -c %s -- "$file" 2>/dev/null || echo 0)
  (( bytes > 0 && bytes <= 5242880 )) || continue
  result=$(timeout 12 rspamc -j -h 127.0.0.1:11333 symbols < "$file" 2>/dev/null) || { ((failed+=1)); ((scanned+=1)); ((scanned>=limit)) && break; continue; }
  score=$(printf '%s\n' "$result" | python3 -c 'import sys,json; s=sys.stdin.read(); n=s.find("{"); d=json.loads(s[n:]) if n>=0 else {}; v=d.get("score"); print(v if isinstance(v,(float,int)) else "")' 2>/dev/null || true)
  if [[ -z "$score" ]]; then ((failed+=1))
  elif awk -v s="$score" 'BEGIN{exit !(s>=8)}'; then
    dst="$root/.Junk/cur/$(basename "$file")"
    if [[ -e "$dst" ]]; then ((failed+=1))
    else mv -n -- "$file" "$dst"; ((moved+=1)); fi
  fi
  ((scanned+=1)); ((scanned>=limit)) && break
done < <(find "$root/cur" "$root/new" -maxdepth 1 -type f -print0)
echo "scanned=$scanned moved_to_junk=$moved errors=$failed"
echo 'No permanent deletions'
