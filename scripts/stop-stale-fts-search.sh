#!/usr/bin/env bash
set -Eeuo pipefail
pid=324914
echo '=== Stop verified stale doveadm search ==='
if [ ! -d "/proc/$pid" ]; then echo "target_pid_absent=yes; nothing to stop"; exit 0; fi
cmd=$(tr '\0' ' ' <"/proc/$pid/cmdline")
case "$cmd" in
  *'doveadm search -u titi mailbox INBOX TEXT __pouge_fts_probe_9f71e2b48a__'*) ;;
  *) echo 'Target PID does not match the exact stalled benchmark command; refusing to stop'; exit 3 ;;
esac
elapsed=$(ps -p "$pid" -o etimes= | tr -d ' ')
[[ "$elapsed" =~ ^[0-9]+$ ]] && (( elapsed >= 1800 )) || { echo 'Target process too recent; refusing to stop'; exit 4; }
echo "matched_stale_search_pid=$pid age_seconds=$elapsed"
kill -TERM "$pid"
sleep 3
if kill -0 "$pid" 2>/dev/null; then echo 'search_process_still_present=yes (not force-killed)'; else echo 'search_process_stopped=yes'; fi
echo "dovecot_state=$(systemctl is-active dovecot || true)"
echo 'Indexer is deliberately not stopped'
