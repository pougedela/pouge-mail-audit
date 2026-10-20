#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
root=/home/titi/Maildir
limit="${SCAN_LIMIT:-1000}"
[[ "$limit" =~ ^[0-9]+$ ]] && ((limit >= 1 && limit <= 1000)) || exit 2
[[ -d "$root/cur" && -d "$root/new" ]] || exit 2
# Create the standard Maildir++ Junk folder with mailbox ownership, if absent.
[[ ! -L "$root/.Junk" ]] || { echo 'Unexpected Junk symlink; abort'; exit 2; }
owner=$(stat -c '%u' "$root")
group=$(stat -c '%g' "$root")
for d in "$root/.Junk" "$root/.Junk/cur" "$root/.Junk/new" "$root/.Junk/tmp"; do
  if [[ ! -d "$d" ]]; then
    [[ ! -e "$d" ]] || { echo 'Unexpected Junk path; abort'; exit 2; }
    install -d -m 700 -o "$owner" -g "$group" -- "$d"
  fi
done
echo 'Junk Maildir verified'
scanned=0; moved=0; failed=0
echo 'Tiphaine: newest-first by file modification date; move score >= 8 to Junk'
# Process newest filesystem modification times first.
while IFS= read -r -d '' entry; do
  file="${entry#* }"
  bytes=$(stat -c %s -- "$file" 2>/dev/null || echo 0)
  (( bytes > 0 && bytes <= 5242880 )) || continue
  result=$(timeout 12 rspamc -j -h 127.0.0.1:11333 symbols < "$file" 2>/dev/null) || { ((failed+=1)); ((scanned+=1)); ((scanned>=limit)) && break; continue; }
  score=$(printf '%s\n' "$result" | python3 -c 'import sys,json; s=sys.stdin.read(); n=s.find("{"); d=json.loads(s[n:]) if n>=0 else {}; v=d.get("score"); print(v if isinstance(v,(float,int)) else "")' 2>/dev/null || true)
  if [[ -z "$score" ]]; then ((failed+=1))
  elif awk -v s="$score" 'BEGIN{exit !(s>=8)}'; then
    dst="$root/.Junk/cur/$(basename "$file")"
    if [[ -e "$dst" ]]; then ((failed+=1))
    elif mv -n -- "$file" "$dst" && [[ ! -e "$file" ]]; then ((moved+=1))
    else ((failed+=1)); fi
  fi
  ((scanned+=1)); ((scanned>=limit)) && break
done < <(find "$root/cur" "$root/new" -maxdepth 1 -type f -printf '%T@ %p\0' | sort -z -nr)
echo "scanned=$scanned moved_to_junk=$moved errors=$failed"
echo 'No permanent deletions'
