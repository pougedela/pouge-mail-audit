#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
target=/var/www/html
version=1.6.19
checksum=c47fd99cd7cbb7aee2557d8ca614a4c51e91f6fa3767ca4ce32c6126f9ebff5b
url="https://github.com/roundcube/roundcubemail/releases/download/${version}/roundcubemail-${version}-complete.tar.gz"
echo '=== Upgrade active Roundcube 1.6.1 to patched 1.6.19 LTS ==='
[[ $(id -u) == 0 ]] || exit 2
[[ -f "$target/program/include/iniset.php" && -f "$target/index.php" && -f "$target/config/config.inc.php" ]] || { echo 'Active Roundcube layout unrecognized'; exit 2; }
grep -Fq "define('RCMAIL_VERSION', '1.6.1')" "$target/program/include/iniset.php" || { echo 'Version unexpected, refusing upgrade'; exit 2; }
for tool in php rsync tar curl sha256sum apache2ctl; do command -v "$tool" >/dev/null || { echo "Missing $tool"; exit 2; }; done
apache2ctl configtest >/dev/null
systemctl is-active --quiet apache2
[[ $(df -Pm /var/www | awk 'NR==2{print $4}') -ge 6000 ]] || { echo 'Insufficient free disk'; exit 2; }
if ! php -r 'exit(extension_loaded("mysqli") || extension_loaded("pdo_mysql") ? 0 : 2);'; then echo 'PHP MySQL extension missing'; exit 2; fi
work=$(mktemp -d /root/roundcube-upgrade-XXXXXXXX)
chmod 700 "$work"
echo "backup_dir=$work"
echo 'Downloading official signed-by-checksum release artifact'
curl -fsSL --connect-timeout 15 --max-time 150 "$url" -o "$work/roundcube.tar.gz"
printf '%s  %s\n' "$checksum" "$work/roundcube.tar.gz" | sha256sum -c -
mkdir "$work/release"
tar --no-same-owner -xzf "$work/roundcube.tar.gz" -C "$work/release"
source_dir="$work/release/roundcubemail-${version}"
[[ -x "$source_dir/bin/installto.sh" || -f "$source_dir/bin/installto.sh" ]] || { echo 'Unexpected archive structure'; exit 2; }
grep -Fq "define('RCMAIL_VERSION', '${version}')" "$source_dir/program/include/iniset.php" || { echo 'Release version mismatch'; exit 2; }
echo 'Backing up active Roundcube tree'
tar -C /var/www -czf "$work/roundcube-webroot-before.tar.gz" html
[[ -s "$work/roundcube-webroot-before.tar.gz" ]] || exit 2
echo 'Backing up Roundcube MySQL database (credentials not logged)'
php -r '
$config=[]; require $argv[1];
$dsn=$config["db_dsnw"]??"";
$u=parse_url($dsn);
if (!$u || ($u["scheme"]??"")!=="mysql" || empty($u["path"]) || empty($u["user"])) {fwrite(STDERR,"Unsupported DB DSN, abort before changes\n");exit(2);}
$host=$u["host"]??"localhost";$port=$u["port"]??3306;
$database=ltrim($u["path"],"/");
if(!preg_match("/^[a-zA-Z0-9_]+$/",$database)){exit(3);}
$fp=fopen($argv[2],"wb");
fwrite($fp,"[client]\nuser=\"".addcslashes(rawurldecode($u["user"]), "\\\"")."\"\npassword=\"".addcslashes(rawurldecode($u["pass"]??""), "\\\"")."\"\nhost=\"".addcslashes($host,"\\\"")."\"\nport=".$port."\n");
fclose($fp); chmod($argv[2],0600);
file_put_contents($argv[3],$database);
' "$target/config/config.inc.php" "$work/mysql-client.cnf" "$work/db-name"
command -v mysqldump >/dev/null || { echo 'mysqldump missing; abort'; exit 2; }
database=$(cat "$work/db-name")
mysqldump --defaults-extra-file="$work/mysql-client.cnf" --single-transaction --routines --triggers -- "$database" > "$work/roundcube-before.sql"
[[ -s "$work/roundcube-before.sql" ]] || { echo 'Database backup empty, abort'; exit 2; }
rm -f "$work/mysql-client.cnf" "$work/db-name"
echo 'Installing official Roundcube release (database migration may occur)'
cd "$source_dir"
php bin/installto.sh -y "$target"
grep -Fq "define('RCMAIL_VERSION', '${version}')" "$target/program/include/iniset.php"
php -l "$target/index.php"
php -l "$target/config/config.inc.php"
apache2ctl configtest
# Remove the public installer after a successful migration. A full backup exists.
if [ -d "$target/installer" ]; then mv "$target/installer" "$work/installer-after-upgrade"; fi
echo "roundcube_version=$version"
echo 'Upgrade succeeded. No mail/IMAP services restarted.'
echo 'Backup of original files and DB kept under protected root directory.'
echo 'On failure after migration, restore both webroot AND database from this backup; do not restore only files.'
