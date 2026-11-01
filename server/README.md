# Home Server: Proxmox + OMV

Current architecture, reviewed 2026-11-01: Proxmox VE on the system SSD and
OMV 8 / Debian 13 in VM 100. Data, UserData and Backups HDDs are passed through
to OMV; an independent disk mounted at /mnt/proxmox-backups stores VM backups.
The old Debian 9 / OMV 4 setup is migration history, not installation guidance.

## Services

| Component | Current configuration / documentation |
| --- | --- |
| Portal | [Independent nginx/PHP portal](web/README.md), separate from OMV admin |
| Nextcloud Files | [Deployment, personal HDD storage and new-user CLI](docker/nextcloud/README.md) |
| GitLab | [Fresh deployment](docker/gitlab/README.md); old 15.11 data retained separately |
| OpenClaw | [Imported OMV container](docker/openclaw/README.md) |
| Vaultwarden | [Compose](docker/vaultwarden/docker-compose.yml), [encrypted backup](backups/docker/vaultwarden/backup-vaultwarden.sh) |
| Transmission / TeamSpeak | Native OMV services restored; Transmission HTTPS [frontend](nginx/transmission) |
| WireGuard gateway | [Proxmox runtime and host relays](docker/vpn-gateway/README.md), [monitor](monit/proxmox/VPN.md) |
| Monit OMV | [Checks, status collector and Unix-socket web proxy](monit/omv/README.md) |
| Monit Proxmox | [UPS, temperatures and VPN](monit/proxmox/README.md) |
| Telegram | [SMTP bridge](docker/monit-telegram/README.md); independent bots/queues on both hosts |
| Fail2ban | [OMV SSH jail](fail2ban/jail.d/omv.local), not the removed legacy jail files |
| APC UPS | [Proxmox settings and shutdown ownership](apcupsd/proxmox/README.md), [portal integration](monit/proxmox/UPS-PORTAL.md) |
| TLS renewal | [Certbot webroot + private proxy + nginx deploy hook](letsencrypt/README.md) |
| Docker firewall | [Published-port restrictions](docker/firewall/README.md); reconcile with actual host rules |

OMV manages mounted storage and Samba. The portal is /var/www/server-home,
not a replacement index.php in OMV's own document root. Nextcloud replaces
File Browser; Netdata restoration was cancelled. Personal .config was migrated
and two other users confirmed access. Repository Compose files are reviewed
templates, not complete copies of private live configuration.

## Backups

- [Daily file mirror](backups/backup-daily.sh): all UserData and Data/Software,
  with mount guards before rsync --delete. New personal HDD folders are included.
- [OMV system-disk backup](backups/proxmox/README.md): only VM scsi0; physical
  HDDs are explicitly excluded. The first archive was created on 2026-11-01,
  OMV is running again; zstd/VMA verification is in progress, not yet confirmed.
- Proxmox host configuration and recovery materials still need a separate backup.
- [Encrypted Google Drive copy](docker/rclone-cloud/README.md), plus dedicated
  application backups. A VM root-disk backup does not include Data/UserData HDDs.
- [MacBook ZIP uploads](../scripts/backup_macOS.sh) and the restored
  [monthly marker check](monit/omv/scripts/macbook_backup.sh) are independent
  of Time Machine. Deploy/test the restored check on OMV before claiming it active.
- Time Machine is deferred until the new MacBook. Its retained Monit scripts
  and [weekly ColdBackup script](backups/backup-weekly.sh) are NOT currently
  enabled. The weekly script copies only Data/TimeMachine; review mounts,
  disk ownership and backup consistency before using it again.

Do not remove rollback archives, old GitLab data or the read-only old SSD until
independent backups and a recovery test are verified. Schedule/retention and
a controlled UPS shutdown test remain outstanding. Change the Nextcloud bootstrap
admin password at the end of setup.

## Migration And VPS

[Migration history and remaining tasks](migration/README.md).
Permanent VPN runtime files now live in docker/vpn-gateway, not migration.
No access to either server is performed by the local repository tools.

[VPS](vps/README.md) remains a separate deployment. Its historical WireGuard
Docker guide explains the original topology; use the current gateway README for
Proxmox runtime instructions.

[Back to dotfiles](../README.md)
