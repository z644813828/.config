# Server Home After Migration

The portal is independent of OMV 8's generated web interface. Do not replace
`/var/www/openmediavault` or its generated nginx site with the legacy files.
Replace `server.example.invalid` in the nginx template with the deployment
hostname and certificate directory before enabling it.

- Public portal: HTTPS 443, HTTP 80 redirects except for ACME challenge files.
- OMV administration: HTTPS 8444, with its existing IP allowlist.
- `/openmediavault.php` redirects to OMV on port 8444 on the same host.
- The portal uses a separate PHP 8.4 FPM pool running as `www-data`.
- Only `index.php` and the IP-allowlisted `/apcupsd.php` endpoint are executable.
  Other PHP scripts remain disabled.
- Dotfiles, including `.env`, are denied by nginx.

Deploy only `index.php`, `dist/`, and the private runtime `.env` into
`/var/www/server-home`. Do not copy this entire repository directory into the
document root. Keep its files owned by root, readable by group `www-data`, and
inaccessible to others. The web worker must not be able to modify the code.

Install `server-home-fpm.conf` as
`/etc/php/8.4/fpm/pool.d/server-home.conf`, and `server-home.nginx.conf` as
`/etc/nginx/sites-available/server-home`. Enable the nginx site only after OMV
has released ports 80 and 443. Validate both configurations before reloading.
Back up existing files before replacing any deployed configuration.

The restored `.env` can contain private links. Never commit or print it.
Service status collection and the APC endpoint require separate deployment;
the portal must not fabricate healthy status for unavailable collectors.

The migrated collector reads `/var/www/server-home/.env` and writes its JSON
atomically to `/var/lib/monit/server-home/service-status.json`. Link that file
as `/var/www/server-home/service-status.json`; keep the containing directory
readable by the portal worker. The output is under Monit's existing writable
state directory, so its systemd sandbox need not allow writes to the web code.
Monit's worker also needs read access to the runtime `.env`; do not relax the
existing root ownership or give the PHP worker write access to it.

The gateway relay for TCP 8444 targets OMV at `192.168.2.254:8444`. Do not expose
the administration port through the router's public WAN forwarding.

## Migrated Service Tiles

FileBrowser is replaced by Nextcloud Files on HTTPS 8880 using the collector's
`nextcloud` status. Proxmox VE uses its `proxmox` status and a private management
URL, defaulting to `https://192.168.2.250:8006/`, or WG `10.80.0.10:8006` when
the portal is opened on that WG address. Set `OMV_PROXMOX_URL` in the existing
private `.env` to override this. No WAN forwarding of 8006 is implied.
Monit links now use private HTTPS 2812, not the legacy public port 4000;
`OMV_MONIT_URL` can override the inferred LAN/WG endpoint. Monit still requires
the configured VPN/IP allowlist and login. A WG 2812 relay is a separate task.

Deploy the updated `index.php`, `dist/images/Nextcloud.svg` and
`dist/images/Proxmox.png` only. Back up the existing index first; preserve the
runtime `.env`, generated status JSON/symlink and OMV-generated web configuration.
Do not deploy sample hostnames or replace the live `.env` with repository files.

Run PHP/link tests with `python3 -m unittest discover -s server/web -p test_portal.py`.
Optional browser tests use Playwright with system Chromium and test desktop and
mobile layouts, local images, status popovers and management links. Fixtures
contain only dummy configuration and disable external requests; they never read
the live `.env`. The old filebrowser status alias is excluded from the overall
count when nextcloud is present.
Netdata was removed at the user's request. Its tile and collector probe are
retired; the portal also ignores an old netdata record until the running
collector is updated. No package uninstall or host configuration change is
implied by this portal update.

Upstream logo assets (served locally, not hotlinked):
- Nextcloud: https://github.com/nextcloud/server/blob/stable34/core/img/logo/logo.svg
- Proxmox: https://github.com/proxmox/pve-manager/blob/master/www/images/logo-128.png

## UPS Snapshot

The prepared APC page reads `/var/lib/monit/server-home/ups-status.json`, not a
local apcupsd daemon or a shell command. See the staged deployment procedure in
[UPS portal integration](../monit/proxmox/UPS-PORTAL.md) for a restricted SSH
exporter on Proxmox, host-key pinning and OMV's root-only snapshot fetcher.
Do not expose NIS or give the PHP worker SSH credentials. The exact nginx
location includes the existing IP allowlist. Missing or older-than-three-minute
snapshots return HTTP 503, while the public tile reports unknown rather than OK.
The updated page uses native fetch, with no legacy jQuery dependency.
