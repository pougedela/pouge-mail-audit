#!/usr/bin/env bash
set -Eeuo pipefail
. /etc/os-release
[ "${VERSION_CODENAME:-}" = noble ] || exit 2
[ "$(id -u)" -eq 0 ] || exit 2
echo '=== Clean obsolete Apache PHP 7.4 link ==='
apache2ctl -t
test -f /etc/apache2/mods-enabled/php8.3.load
p=/etc/apache2/mods-enabled/php7.4.load
if [ -L "$p" ] && [ ! -e "$p" ]; then
  backup="/root/apache-php74-stale-$(date -u +%Y%m%dT%H%M%SZ)"
  mkdir -m 700 "$backup"
  cp -P "$p" "$backup/"
  rm -- "$p"
  if ! apache2ctl -t; then
    cp -P "$backup/php7.4.load" "$p"
    echo 'Syntax issue after cleanup: link restored'
    exit 3
  fi
  systemctl reload apache2
  systemctl is-active --quiet apache2
  echo 'obsolete_php74_broken_link=removed'
else
  echo 'obsolete_php74_broken_link=not_present_or_not_broken_no_change'
fi
echo '=== Postfix chroot CA mismatch inspection (read only) ==='
postfix check 2>&1 | grep -E 'warning: .*(/var/spool/postfix/etc/ssl/certs/|compatibility)' | sed -E 's#(https?://)[^ /]+#[URL]#g' || true
for name in Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.pem GlobalSign_ECC_Root_CA_-_R4.pem ssl-cert-snakeoil.pem; do
 a="/etc/ssl/certs/$name"; b="/var/spool/postfix/etc/ssl/certs/$name"
 if [ -e "$a" ] && [ -e "$b" ]; then
  if cmp -s "$a" "$b"; then echo "cert_$name=identical"; else echo "cert_$name=mismatch"; fi
 else
  echo "cert_$name=missing_path"
 fi
done
echo 'Postfix certificate data left unchanged; no restart of mail services.'
