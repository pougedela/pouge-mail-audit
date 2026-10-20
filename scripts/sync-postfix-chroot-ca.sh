#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || exit 2
. /etc/os-release
[ "${VERSION_CODENAME:-}" = noble ] || exit 2
echo '=== Repair selected Postfix chroot certificate copies ==='
backup="/root/postfix-ca-sync-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 700 "$backup"
for name in Autoridad_de_Certificacion_Firmaprofesional_CIF_A62634068.pem GlobalSign_ECC_Root_CA_-_R4.pem ssl-cert-snakeoil.pem; do
 src="/etc/ssl/certs/$name"
 dest="/var/spool/postfix/etc/ssl/certs/$name"
 [ -r "$src" ] && [ -f "$dest" ] || { echo "Missing expected certificate path: $name"; exit 3; }
 [ ! -L "$dest" ] || { echo "Refusing symlink destination: $name"; exit 3; }
 cp -a -- "$dest" "$backup/$name"
 install -m 0644 -- "$(readlink -f "$src")" "$dest"
 cmp -s "$src" "$dest" || { cp -a -- "$backup/$name" "$dest"; echo "Mismatch after copying: $name"; exit 4; }
 echo "synced=$name"
done
echo '=== Postfix config check ==='
postfix check 2>&1 | sed -E 's#(https?://)[^ /]+#[URL]#g' || true
echo '=== Status ==='
echo "postfix=$(systemctl is-active postfix || true)"
echo "backup=$backup"
echo 'No Lets Encrypt private keys, mailboxes, or other files touched; no restart performed.'
