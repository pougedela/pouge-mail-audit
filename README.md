# pouge.net — antispam diagnostic (read-only, SSH password)

Initial audit ONLY. No server changes, no restarts, no message deletion.

## GitHub setup

1. Use a **private** GitHub repository named `pouge-mail-audit`.
2. On the VPS, use a **dedicated unprivileged audit account** with an SSH password. Avoid `root` and sudo rights. Do not change system-wide SSH authentication solely for this audit.
3. Verify the VPS SSH host public-key fingerprint using the OVH console or another trusted channel. Put the corresponding verified `known_hosts` line in GitHub Actions secret `VPS_KNOWN_HOSTS`. For nonstandard ports, use `[host]:port` format. Never trust an unverified `ssh-keyscan` result.
4. Create GitHub Actions secret `VPS_PASSWORD` (dedicated SSH password). **Never put credentials in chat, code or logs.**
5. Set GitHub Actions repository variables: `VPS_HOST` (hostname/IP), `VPS_USER` (audit account), `VPS_PORT` (default 22).
6. Trigger *Actions > VPS mail audit (read-only) > Run workflow* manually.

## Security and limitations

Uses `sshpass -e` with GitHub Secrets and strict SSH host verification. Password authentication remains less secure than dedicated SSH keys; restrict repo access. GitHub-hosted runner IPs can change, potentially affecting SSH firewall access.

Some information may be unavailable to the unprivileged audit account. This script doesn't perform a live open-relay test; DNS SPF/DMARC checks do not cover DKIM selectors. Log counts cover the current readable mail log, **not exactly 24 hours**. Review the script before execution.
