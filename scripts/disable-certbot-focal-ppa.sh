#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || exit 2
. /etc/os-release
[ "${VERSION_CODENAME:-}" = jammy ] || exit 2
echo '=== Disable obsolete Certbot focal PPA only ==='
stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="/root/apt-before-certbot-cleanup-$stamp"
install -d -m 700 "$backup"
changed=0
found=0
for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
 [ -f "$f" ] || continue
 if grep -Ei 'certbot.*focal' "$f" >/dev/null; then
   found=$((found+1))
   if grep -Ei '^[[:space:]]*deb(-src)?[[:space:]].*certbot.*focal' "$f" >/dev/null; then
     install -m 600 "$f" "$backup/$(basename "$f").bak"
     sed -i -E '/^[[:space:]]*deb(-src)?[[:space:]].*certbot.*focal/s/^/# disabled obsolete Certbot focal PPA: /' "$f"
     echo "disabled_certbot_focal_file=$f"
     changed=$((changed+1))
   else
     echo "certbot_focal_already_commented_in=$f"
   fi
 fi
done
echo "matching_files=$found"
echo "changed_files=$changed"
echo 'Active Certbot focal entries remaining:'
grep -El '^[[:space:]]*deb(-src)?[[:space:]].*certbot.*focal' /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true
echo 'APT source syntax and availability check (no package changes):'
apt-get update -qq
echo 'APT update succeeded.'
echo "certbot_installed=$(dpkg-query -W -f='${Version}' certbot 2>/dev/null || echo missing)"
echo "certbot_timer=$(systemctl is-active certbot.timer 2>/dev/null || true)"
echo "certbot_hook=$([ -x /etc/letsencrypt/renewal-hooks/deploy/90-pouge-mail-reload.sh ] && echo present || echo missing)"
echo 'No OS upgrade, package install or service restart done.'
