#!/usr/bin/env bash
set -Eeuo pipefail
[[ $(id -u) == 0 ]] || { echo 'root required'; exit 2; }
command -v certbot >/dev/null || { echo 'Certbot absent; detect renewal client before configuring hooks'; exit 2; }
test -d /etc/letsencrypt/renewal || { echo 'No Certbot renewal configs; abort'; exit 2; }
systemctl is-active --quiet postfix || { echo 'Postfix inactive; abort'; exit 2; }
systemctl is-active --quiet dovecot || { echo 'Dovecot inactive; abort'; exit 2; }
command -v postfix >/dev/null && command -v doveconf >/dev/null
postfix check
doveconf -n >/dev/null
target=/etc/letsencrypt/renewal-hooks/deploy/90-pouge-mail-reload.sh
install -d -m 755 /etc/letsencrypt/renewal-hooks/deploy
if [ -e "$target" ]; then echo 'Existing mail renewal hook detected; refusing overwrite'; exit 3; fi
tmp=$(mktemp /etc/letsencrypt/renewal-hooks/deploy/.mailhook.XXXXXX)
trap 'rm -f "$tmp"' EXIT
cat >"$tmp" <<'HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail
exec 9>/run/lock/pouge-mail-cert-reload.lock
flock -w 30 9
if [[ -n "${RENEWED_LINEAGE:-}" ]]; then
  cert="${RENEWED_LINEAGE}/cert.pem"
  test -r "$cert"
  openssl x509 -in "$cert" -noout -checkend 3600 >/dev/null || { logger -t pouge-mail-renew 'Certificate already near expiration; no reload'; exit 1; }
fi
postfix check
doveconf -n >/dev/null
systemctl reload postfix
systemctl reload dovecot
systemctl is-active --quiet postfix
systemctl is-active --quiet dovecot
logger -t pouge-mail-renew 'Postfix and Dovecot reloaded after successful certificate deployment'
HOOK
chmod 755 "$tmp"
mv -n "$tmp" "$target"
trap - EXIT
echo "installed_hook=$target"
echo 'Deploy-hook runs only after successful Certbot renew/deploy events.'
echo 'No mail services reloaded during installation.'
echo 'Note: non-Certbot ACME clients need a different integration.'
