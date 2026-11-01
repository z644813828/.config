# Backup Coverage

Current source templates, not a claim that every job is deployed.

| Job | Scope | Status |
| --- | --- | --- |
| backup-daily.sh | All UserData and Data/Software to Backups | Previous live run passed; reviewed UUID/mount-guard source updated locally |
| docker/vaultwarden/backup-vaultwarden.sh | PostgreSQL dump + attachments/config/Compose, encrypted | Restored live job tested; restore still to test |
| docker/gitlab/backup-gitlab.sh | Current running GitLab application backup + config/secrets/Compose, encrypted | Manual run/decrypt check confirmed; root cron 01:30 MSK added; restore still pending |
| vps/pull-vps-backups-from-ftp.py | FTP copies of three VPS backup trees | Manual run passed, root cron 02:30 MSK added; policy reduced to 30 days/minimum three, update private env on target |
| proxmox/backup_omv.py | VM 100 system disk only, physical HDDs excluded | Created; zstd/VMA and encrypted Drive cryptcheck passed 2026-11-01; schedule/restore pending |
| proxmox/backup_host.py | Proxmox config/keys/pmxcfs, two host Docker images/rootfs and notifier queue | Created (115531Z); local validation and encrypted Drive cryptcheck passed; schedule/restore pending |
| ../docker/rclone-cloud/workspace/scripts/backup-to-gdrive.sh | Offsite copy of configured Backups source | Restored; verify the next scheduled success |
| backup-weekly.sh | Data/TimeMachine only to ColdBackup | Deferred until the new MacBook / reviewed Time Machine setup |

The daily source now checks UserData, Data and Backups mounts and Software's
existence before any rsync --delete. A success marker is atomically replaced
only after both transfers and size/free-space reporting succeed. It mirrors
deletions; it is not versioned history. New user folders inside UserData are
included automatically. Do not install or run it before confirming disk UUIDs.

The GitLab job discovers the actual config/data bind paths from Docker so a live
gitlab-fresh directory is not confused with preserved old gitlab data. It requires
the encryption key; it does not generate/replace it. Archive format remains
compatible with the old OpenSSL invocation. Read ../docker/gitlab/README.md.

Before deploying updates, preserve the existing scripts and cron entries, review
rsync dry-run changes and run jobs manually. Repository edits do not install jobs
or enable schedules. Never run old and new jobs concurrently.

Proxmox upload helper now supports optional --prune: two verified local/cloud
generations per VM and host, protected copies retained. Updated cron template
requests it; target deployment/first rotation still to verify. VPS 30-day policy
is local only: OMV's rclone copy leaves older VPS cloud files untouched.

Still required: verify scheduled runs and rotation on target, consistent Nextcloud
database/config/data backups and isolated restore tests.
The VM system-disk archive excludes HDD bind data, and a host config archive
does not by itself provide a bootable system image.

MacBook ZIP archive freshness is monitored separately in
../monit/omv/scripts/macbook_backup.sh. Time Machine is not its data source.

Tests: python3 -B -m unittest discover -s server/backups -p 'test_*.py'.
