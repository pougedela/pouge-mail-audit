#!/usr/bin/env bash
set -Eeuo pipefail
# Read-only retrospective scan. No message headers/bodies, filenames or subjects in CI logs.
export LC_ALL=C
limit="${SCAN_LIMIT:-10}"
[[ "$limit" =~ ^[0-9]+$ ]] && (( limit >= 1 && limit <= 100 )) || { echo "SCAN_LIMIT must be 1..100"; exit 1; }
command -v rspamc >/dev/null || { echo "rspamc missing"; exit 1; }
systemctl is-active --quiet rspamd || { echo "Rspamd inactive"; exit 1; }
total=0
for account in titi pouge; do
  root="/home/$account/Maildir"
  echo "account=$account"
  if [[ ! -d "$root/cur" || ! -d "$root/new" ]]; then echo "maildir not confirmed; skipped"; continue; fi
  processed=0; failed=0; over15=0; over8=0; other=0
  while IFS= read -r -d '' file; do
    [[ -f "$file" ]] || continue
    # Only check a sample. Skip large items to avoid excessive processing.
    bytes=$(stat -c %s -- "$file" 2>/dev/null || echo 0)
    (( bytes > 0 && bytes <= 5242880 )) || continue
    output=$(timeout 12 rspamc -j -h 127.0.0.1:11333 symbols < "$file" 2>/dev/null) || { ((failed+=1)); ((processed+=1)); ((processed>=limit)) && break; continue; }
    score=$(printf '%s\n' "$output" | python3 -c 'import json,sys; raw=sys.stdin.read(); pos=raw.find("{"); data=json.loads(raw[pos:]) if pos>=0 else {}; score=data.get("score"); print(score if isinstance(score,(int,float)) else "")' 2>/dev/null || true)
    if [[ -n "$score" ]]; then
      if awk -v s="$score" 'BEGIN{exit !(s>=15)}'; then ((over15+=1))
      elif awk -v s="$score" 'BEGIN{exit !(s>=8)}'; then ((over8+=1))
      else ((other+=1)); fi
    else ((failed+=1)); fi
    ((processed+=1))
    ((processed>=limit)) && break
  done < <(find "$root/cur" "$root/new" -maxdepth 1 -type f -print0 2>/dev/null)
  echo "scanned=$processed score_ge_15=$over15 score_8_to_15=$over8 lower=$other parse_or_scan_failed=$failed"
  ((total+=processed))
  if ((processed > 0 && failed == processed)); then echo "ERROR: No usable scores; do not move any mail."; exit 2; fi
done
echo "total_scanned=$total"
echo "Read-only sampling finished. No message moved, deleted, or modified."
