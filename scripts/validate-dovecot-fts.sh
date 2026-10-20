#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== FTS post-activation validation ==='
systemctl is-active --quiet dovecot
doveconf -n >/dev/null
plugins=$(doveconf -h mail_plugins)
echo "fts_plugin_active=$([[ "$plugins" == *fts_xapian* ]] && echo yes || echo no)"
[[ "$plugins" == *fts_xapian* ]] || exit 2
echo "fts_backend=$(doveconf -h -f plugin/fts 2>/dev/null || true)"
echo 'Dovecot mail user lookup:'
for u in titi pouge; do doveadm user "$u" >/dev/null && echo "$u=yes" || echo "$u=no"; done
echo 'Check recent Dovecot FTS/index errors (count only):'
journalctl -u dovecot --since '15 minutes ago' -o cat --no-pager 2>/dev/null | grep -Eic 'fts.*(error|fail)|indexer.*(error|fail)' || true
echo 'No mailbox indexing or search executed'
