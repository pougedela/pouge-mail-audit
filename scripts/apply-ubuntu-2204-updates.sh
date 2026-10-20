#!/usr/bin/env bash
set -Eeuo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'root required'; exit 2; }
. /etc/os-release
[ "${VERSION_CODENAME:-}" = "jammy" ] || { echo 'Expected Ubuntu 22.04'; exit 2; }
packages=(ca-certificates liblzma5 libopeniscsiusr open-iscsi open-vm-tools python3-jwt xz-utils)
echo '=== Apply targeted Ubuntu 22.04 updates ==='
echo 'Preflight APT resolver:'
sim=$(apt-get -s --only-upgrade install "${packages[@]}")
printf '%s\n' "$sim" | grep -E '^[0-9]+ upgraded,|^Remv ' || true
if printf '%s\n' "$sim" | grep -q '^Remv '; then echo 'ERROR: removal proposed'; exit 3; fi
if ! printf '%s\n' "$sim" | grep -Eq '^[0-9]+ upgraded, 0 newly installed, 0 to remove'; then echo 'ERROR: unexpected apt resolution'; exit 4; fi
for unit in postfix dovecot mysql apache2 rspamd; do
 systemctl is-active --quiet "$unit" || { echo "ERROR: $unit inactive before upgrade"; exit 5; }
done
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
apt-get -y --only-upgrade -o Dpkg::Options::=--force-confold install "${packages[@]}"
echo '=== Package states ==='
dpkg --audit
for package in "${packages[@]}"; do dpkg-query -W -f='${binary:Package}=${Version}\n' "$package"; done
echo '=== Post-update services ==='
bad=0
for unit in postfix dovecot mysql apache2 rspamd fail2ban; do
 state=$(systemctl is-active "$unit" 2>/dev/null || true)
 echo "$unit=$state"
 [ "$state" = active ] || bad=1
done
echo "reboot_required=$([ -e /var/run/reboot-required ] && echo yes || echo no)"
[ "$bad" -eq 0 ] || { echo 'ERROR: some services inactive'; exit 6; }
echo 'Targeted Jammy updates finished; OS release upgrade NOT started.'
