#!/usr/bin/env bash
set -Eeuo pipefail
echo 'Dovecot top-level include directives (no credentials):'
grep -nE '^[[:space:]]*!include(_try)?[[:space:]]' /etc/dovecot/dovecot.conf || true
echo 'Dovecot conf.d main include references:'
grep -nE 'conf\.d|\.conf' /etc/dovecot/dovecot.conf | grep -E '!include|^$' || true
echo 'Config file and directory existence:'
for x in /etc/dovecot/dovecot.conf /etc/dovecot/conf.d /etc/dovecot/conf.d/91-pouge-fts-xapian.conf; do
 if [[ -e "$x" ]]; then echo "$x exists"; else echo "$x absent"; fi
done
echo 'Dovecot config parses:'
doveconf -n >/dev/null && echo 'yes'
