#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || exit 2
. /etc/os-release
[ "${VERSION_CODENAME:-}" = noble ] || { echo 'Expected Ubuntu 24.04'; exit 2; }
echo '=== Restore Apache PHP module after Noble upgrade ==='
backup="/root/apache-php-module-fix-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 700 "$backup"
cp -a /etc/apache2/mods-enabled "$backup/"
echo 'Backing up Apache enabled module links complete'
if ! dpkg-query -W -f='${Status}' libapache2-mod-php8.3 2>/dev/null | grep -q 'install ok installed'; then
 echo 'ERROR: libapache2-mod-php8.3 is not installed. Refusing change.'
 exit 3
fi
test -f /etc/apache2/mods-available/php8.3.load || { echo 'Missing PHP 8.3 Apache module'; exit 4; }
if test -e /etc/apache2/mods-enabled/php8.1.load || test -L /etc/apache2/mods-enabled/php8.1.load; then
 a2dismod php8.1
 echo 'php81_disabled=yes'
fi
a2enmod php8.3
if ! apache2ctl -t; then
 echo 'ERROR: Apache syntax invalid; rolling back module links'
 rm -f /etc/apache2/mods-enabled/php8.3.load /etc/apache2/mods-enabled/php8.3.conf
 cp -a "$backup/mods-enabled/." /etc/apache2/mods-enabled/
 exit 5
fi
systemctl restart apache2
systemctl is-active --quiet apache2
echo 'apache2=active'
for proto in http https; do
 status=$(curl -k -sS -m 10 --resolve www.pouge.net:443:127.0.0.1 --resolve www.pouge.net:80:127.0.0.1 -o /dev/null -w '%{http_code}' "$proto://www.pouge.net/" || true)
 echo "local_${proto}_status=$status"
done
echo 'PHP Apache module corrected. Mail services untouched.'
