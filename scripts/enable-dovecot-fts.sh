#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'root required'; exit 2; }
systemctl is-active --quiet dovecot || { echo 'Dovecot inactive; abort'; exit 2; }
dpkg-query -W -f='${Status}' dovecot-fts-xapian | grep -qx 'install ok installed' || { echo 'Xapian package absent'; exit 2; }
test -d /etc/dovecot/conf.d || exit 2
test -f /etc/dovecot/dovecot.conf || exit 2
target=/etc/dovecot/conf.d/91-pouge-fts-xapian.conf
[ ! -e "$target" ] || { echo 'FTS managed config already exists; abort'; exit 2; }
if doveconf -n | grep -Eiq '^[[:space:]]*(fts|fts_xapian|fts_autoindex)[[:space:]]*='; then
 echo 'Existing FTS configuration detected; abort'; exit 2
fi
backup=/root/pouge-dovecot-fts-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 700 "$backup"
cp -a /etc/dovecot "$backup/config"
cp -a /etc/dovecot/dovecot.conf "$backup/dovecot.conf"
echo "Dovecot configuration backup created in $backup"
rollback() {
 rm -f -- "$target"
 cp -a -- "$backup/dovecot.conf" /etc/dovecot/dovecot.conf
 if doveconf -n >/dev/null 2>&1; then systemctl reload dovecot || true; fi
 echo 'Failed activation; managed FTS configuration removed'
}
trap rollback ERR
cat > "$target" <<'CFG'
# Dovecot 2.3.x with distro packaged fts-xapian.
mail_plugins = $mail_plugins fts fts_xapian
plugin {
  fts = xapian
  fts_xapian = verbose=0
  fts_autoindex = yes
}
service indexer-worker {
  vsz_limit = 2G
}
CFG
# The main dovecot.conf has no discovered conf.d inclusion. Explicitly add only our file.
printf '\n!include /etc/dovecot/conf.d/91-pouge-fts-xapian.conf\n' >> /etc/dovecot/dovecot.conf
doveconf -n >/dev/null
doveconf -h mail_plugins | grep -q fts_xapian
systemctl reload dovecot
systemctl is-active --quiet dovecot
echo 'FTS configuration activated; no full-mailbox indexing started'
echo 'To roll back, remove only the managed config and reload Dovecot after validation.'
trap - ERR
