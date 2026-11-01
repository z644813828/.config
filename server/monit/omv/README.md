# OMV Monit

This directory contains current reviewed checks and selected retained scripts.
It is not a complete snapshot of the current running server.
Do not install every file or overwrite OMV's generated monitrc with this tree.
The old mass installer was removed; do not bulk-copy this directory into conf.d.

## Reviewed Checks

The migration reviewed backup freshness (`check-backups`, `rclone_cloud_backup`),
OpenClaw health, portal status collection, etckeeper, Let's Encrypt expiration,
LAN gateway, public IP changes, router availability/certificate, Fail2ban and
Transmission completion notifications. Configurations are under `conf.d/`,
scripts and their tests under `scripts/`.

Install selected scripts under `/etc/monit/scripts/` and selected configurations
under `/etc/monit/conf.d/`. Keep deployed paths unchanged. Personal domains,
certificate paths and other private settings must be filled in locally.
Global notifications are handled by OMV's existing local Telegram SMTP bridge.
OMV generates its main Monit configuration; no replacement monitrc is shipped.

The portal's StreamDeck check is disabled by default. To restore it, set
`OMV_CHECK_STREAMDECK=true` in the private deployed portal .env. With no value
or `false`, the collector omits it from service-status.json and the overall
status calculation; it does not remove the existing portal tile. This is a
collector option, not an independent Monit service: do not unmonitor the whole
`service_status` collector just to disable StreamDeck.

The public IP checker is `scripts/public_ip.sh`, configured by
`conf.d/public-ip.conf`. The LAN gateway check is `conf.d/lan-gateway.conf`;
it does not restart NetworkManager. When updating an existing deployment,
replace the old public_IP.conf/network-manager.conf rather than installing both
old and new names, and install public_ip.sh with the updated public IP config.

## MacBook ZIP Backup Check

`scripts/macbook_backup.sh` checks the success marker written by
`../../../scripts/backup_macOS.sh` after all ZIP uploads pass remote validation.
The default is UserData/dmitriy/Документы/backup/date on the UUID-mounted HDD.
This is NOT Time Machine. From day 3 of each calendar month it requires a valid,
non-future marker from the current month; days 1-2 are a grace period. A missing
mount is always an error, even during grace. This checks a marker, not ZIP contents.

Install on OMV after transferring both files to /root:

```bash
install -m 750 /root/macbook_backup.sh /etc/monit/scripts/macbook_backup.sh
bash /etc/monit/scripts/macbook_backup.sh
install -m 600 /root/macbook_backup.conf /etc/monit/conf.d/macbook_backup.conf
monit -t && systemctl reload monit
```

The configuration uses the existing global OMV Telegram SMTP alert recipient,
without embedding a personal email. A day-1 grace result does not prove the
monthly backup exists. Actual host deployment is still to be verified.
Optional local environment settings are MACBOOK_BACKUP_MOUNT/MACBOOK_BACKUP_STAMP.

## Deferred And Removed Checks

Time Machine's configuration/script are retained but disabled until the new
MacBook is configured. Review their paths and actual Time Machine layout before
enabling them; keeping the scripts does not make them ready to run unchanged.
MacBook ZIP backup monitoring is restored separately as described above.
Arduino/RPi, SSH-success/GeoIP, old APC log/hdparm/SMART-log and old VPN checks
were not restored and most have now been removed by the user. Host UPS,
temperatures and VPN monitoring belong in `../proxmox/`. A remaining old
vpn_gateway.sh is historical and must not be enabled by the new monitor.

## Tests

From the repository root:

```bash
python3 -B -m unittest discover -s server/monit/omv/scripts -p 'test_*.py'
```
