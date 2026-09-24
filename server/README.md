 # Home Server and NAS

Configuration for the Debian 9 / OpenMediaVault 4 home server: file sharing,
Time Machine, self-hosted services, and backups.

## Services

| Component | Configuration / documentation |
| --- | --- |
| nginx | [HTTPS reverse proxy and access rules](nginx/) |
| WireGuard | [VPS gateway and access to home services](vps/WIREGUARD_DOCKER_GATEWAY.md) |
| Docker firewall | [Published-port restrictions](docker/firewall/README.md) |
| GitLab | [Docker Compose](docker/gitlab/docker-compose.yml) |
| OpenClaw | [Telegram agent](docker/openclaw/README.md), [Docker Compose for migration](docker/openclaw/docker-compose.yml) |
| rclone-cloud | [Encrypted Google Drive backups](docker/rclone-cloud/README.md) |
| Monit | [Main configuration](monit/monitrc), [checks](monit/conf.d/), and [scripts](monit/scripts/) |
| Monit Telegram | [Notification bridge](docker/monit-telegram/README.md) |
| Fail2ban | [SSH protection](jail.local) |
| APC UPS | [Power-event hooks](apcupsd/) |

OpenMediaVault manages disks, SMB/AFP shares, and Time Machine. Vaultwarden
with PostgreSQL provides password storage.

## Backups

- [Server backup scripts](backups/).
- [MacBook archives](../scripts/backup_macOS.sh) and [local disk copies](../scripts/rsync.sh).
- [Off-site backup setup](docker/rclone-cloud/README.md).
- Backup freshness checks are in [Monit](monit/conf.d/).

## VPS

- [VPS](vps/README.md).

[Back to dotfiles](../README.md)
