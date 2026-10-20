# Rspamd rollout plan for pouge.net (staging only)

Current audit showed Postfix and Dovecot active, no active Rspamd service, and no smtpd_milters. A per-user `titi` audit has been added but has not run.

**No files in this directory are automatically applied to the VPS.**

1. Run the latest GitHub Actions audit to locate titi's mailbox and quantify counts. Review actual mail delivery path, overrides in Postfix master.cf, existing sieve rules, current mail logs, and installed packages. Inspect whether Postfix uses a milter elsewhere.
2. Take an off-server backup of /etc/postfix, /etc/dovecot and mailbox metadata. Secure SSH access before enabling a deployment runner; current runner uses root/password with unverified host.
3. On a planned maintenance window, install Rspamd from appropriate supported repository and configure its proxy milter listener bound to localhost. Validate with `rspamadm configtest`, `postfix check` and `ss -ltn`.
4. Apply local.d templates after confirming the installed version, then attach Postfix `smtpd_milters = inet:127.0.0.1:11332` and `milter_default_action = accept` (fail-open on scanning outage); preserve any existing milters if present. DKIM signing via OpenDKIM must continue, including possible master.cf overrides.
5. For observation period, add spam-related headers rather than moving or deleting messages. Setting reject=1000 only prevents ordinary score-based rejection; hard rules, other modules, and early SMTP restrictions may still reject. Test with normal external incoming mail and controlled spam samples.
6. Only after observing false positives, consider a Dovecot Sieve rule for titi that sends marked mail to Junk. Back up existing Sieve filters and confirm mailbox names and LMTP/LDA routing before this step.
7. Monitor delivery counts, rejected/temporary SMTP failures, Rspamd scores and user complaints. Roll back milter integration promptly if messages are delayed or lost.

References:
https://docs.rspamd.com/getting-started/first-setup/
https://docs.rspamd.com/modules/milter_headers/
https://docs.rspamd.com/guides/configuration/fundamentals/
