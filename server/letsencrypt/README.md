# OMV Automatic Certificate Renewal

ASUS certificate installation is manual. Do not copy private keys to the portal
or add router credentials to this directory. The host uses Certbot 4.0.0 and
the existing twice-daily certbot.timer; no additional cron job is required.

## Webroot Migration

The initial renewal configuration used standalone with no hooks. The
running nginx owns port 80, so unattended renewal must not rely on stopping it
or competing with Monit's nginx recovery. Webroot serves challenge files while
all HTTPS applications remain available.

1. In the portal's HTTP server block, add the ACME location from
   `../web/server-home.nginx.conf`. Move the server-level HTTPS return into
   `location /`, or it will also redirect the challenge. Preserve the deployed
   hostname and the rest of the real nginx configuration.
2. Create `/var/www/letsencrypt/.well-known/acme-challenge` root-owned, mode 0755.
   Serve only challenge files, not Nextcloud files, credentials or application
   configuration. Validate with nginx -t and reload nginx.
3. Check a temporary challenge file locally with the correct Host header and
   from mobile data without VPN using plain HTTP port 80. HTTP-01 cannot use
   external port 4430 instead of port 80. Remove the test file after validation.
4. Back up the selected certificate's renewal configuration privately, then use
   `certbot reconfigure --cert-name "$DOMAIN" --webroot -w /var/www/letsencrypt`.
   This tests against staging before saving the new renewal parameters. Do not
   force production renewal just to save authenticator changes.
5. Install `reload-nginx.sh` root-owned mode 0750 as
   `/etc/letsencrypt/renewal-hooks/deploy/20-reload-nginx`. It validates nginx and
   reloads it only; no service stops, private-key copying or router operations.
6. Verify `certbot renew --cert-name "$DOMAIN" --dry-run --run-deploy-hooks`
   and inspect the saved authenticator. Keep the package timer enabled.

The user confirmed the public HTTP challenge-file test on 2026-11-01. The first
`reconfigure` failed because the staging API timed out over the direct path.
After configuring the working proxy, reconfigure successfully saved the webroot
settings. The subsequent `renew --dry-run --run-deploy-hooks` succeeded and
executed the nginx deploy hook. The shell block enabled the package timer and
removed the temporary HTTP test file. The real certificate was not force-renewed.

Certbot labelled the hook's stderr as "error output", but nginx validation
passed and simulated renewal succeeded; nginx -t normally prints diagnostics
to stderr. The remaining Vaultwarden `listen ... http2` deprecation warning is
separate configuration maintenance, not a renewal failure. Future unattended
renewal still depends on proxy availability and public port 80 reaching OMV.

References:
- https://eff-certbot.readthedocs.io/en/stable/using.html#modifying-the-renewal-configuration
- https://letsencrypt.org/docs/challenge-types/#http-01-challenge

## Proxy For ACME Requests

The target test confirmed staging direct ReadTimeout, staging proxy HTTP 200,
and production HTTP 200 both directly and via proxy. Use the working proxy for
Certbot's outgoing ACME HTTPS traffic; incoming HTTP-01 still uses public port 80.

Run `prepare-certbot-proxy.py` as root on OMV. It exclusively creates
`/etc/letsencrypt/proxy.env` mode 0600, copying only the selected HTTPS proxy
into HTTP/HTTPS/ALL proxy variables (both cases). No bot token or chat ID is
copied. Do not print or commit this generated file, and do not shell-source it.
Install `certbot-proxy.conf` at `/etc/systemd/system/certbot.service.d/proxy.conf`
and reload systemd. Keep the standard Certbot ExecStart and timer unchanged.

For manual reconfiguration/testing, use a root transient service with the same
environment file, for example:

```bash
systemd-run --quiet --wait --pipe --collect \
  -p EnvironmentFile=/etc/letsencrypt/proxy.env \
  /usr/bin/certbot reconfigure --cert-name "$DOMAIN" \
  --webroot -w /var/www/letsencrypt
```

Then install the reload hook and run the dry run (with deploy hooks) through the
same transient-service environment. Do not put credentials in CLI arguments or
load the full Telegram environment into Certbot. The proxied reconfiguration
and deploy-hook dry run were verified successfully on the target on 2026-11-01.
The service EnvironmentFile drop-in and standard timer were installed; a future
real unattended renewal has not yet occurred.
