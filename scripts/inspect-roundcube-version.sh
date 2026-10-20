#!/usr/bin/env bash
set -Eeuo pipefail
echo '=== Active Roundcube version inventory (read-only) ==='
for dir in /var/www/html /var/www/roundcubemail-1.6.1 /var/www/backup; do
 [ -f "$dir/program/lib/Roundcube/rcube.php" ] || continue
 echo "path=$dir"
 for file in "$dir/program/include/iniset.php" "$dir/program/lib/Roundcube/rcube.php" "$dir/CHANGELOG" "$dir/composer.json"; do
   [ -r "$file" ] || continue
   grep -m 2 -E 'RCMAIL_VERSION|const VERSION|\"version\"[[:space:]]*:|Roundcube Webmail [0-9]+\.[0-9]+' "$file" 2>/dev/null | head -n 2 || true
 done
 if [ -f "$dir/index.php" ]; then echo 'entrypoint_present=yes'; fi
done
echo 'Apache docroot symlink'
readlink -f /var/www/html
echo 'Potential installer exposure (files only, no HTTP request):'
for f in /var/www/html/installer/index.php /var/www/html/INSTALL /var/www/html/config/config.inc.php; do
 [ -f "$f" ] && echo "present=$f" || true
done
echo 'No version update or configuration modification performed'
