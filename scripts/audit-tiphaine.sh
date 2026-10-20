#!/usr/bin/env bash
set -euo pipefail
echo 'Tiphaine mailbox discovery - metadata only, no modifications'
address='tiphaine.ruellan@pouge.net'
echo "recipient=$address"
for user in tiphaine.ruellan tiphaine ruellan; do
 if id "$user" >/dev/null 2>&1; then
   home=$(getent passwd "$user" | cut -d: -f6)
   echo "system_user=$user home_maildir_present=$([ -d "$home/Maildir/cur" ] && echo yes || echo no)"
   if [ -d "$home/Maildir/cur" ]; then
      for folder in cur new .Junk/cur .Junk/new; do
        [ -d "$home/Maildir/$folder" ] && echo "folder=$folder files=$(find "$home/Maildir/$folder" -maxdepth 1 -type f | wc -l)"
      done
   fi
 fi
done
echo 'Dovecot userdb lookup:'
if doveadm user "$address" >/dev/null 2>&1; then echo 'full address found'; else echo 'full address not found'; fi
echo 'No mail content accessed, deleted or moved'
