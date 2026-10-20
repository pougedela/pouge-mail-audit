#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Identify stale FTS operations (read only) ==='
date -u '+timestamp_utc=%FT%TZ'
echo "dovecot=$(systemctl is-active dovecot || true)"
for pid in $(pgrep -x doveadm || true); do
  [ -r "/proc/$pid/cmdline" ] || continue
  cmd=$(tr '\0' ' ' </proc/"$pid"/cmdline)
  kind=other
  case "$cmd" in
    *'doveadm search '*) kind=search ;;
    *'doveadm index '*) kind=index ;;
  esac
  echo "doveadm_pid=$pid kind=$kind"
  ps -p "$pid" -o pid=,ppid=,etime=,stat=,%cpu=,%mem= || true
  echo "children=$(pgrep -P "$pid" | wc -l)"
done
for pid in $(pgrep -x indexer-worker || true); do
  echo "indexer_pid=$pid"
  ps -p "$pid" -o pid=,ppid=,etime=,stat=,%cpu=,%mem= || true
done
echo 'Xapian size:'
du -sh /home/titi/Maildir/xapian-indexes 2>/dev/null || true
echo 'No process stopped and no configuration modified'
