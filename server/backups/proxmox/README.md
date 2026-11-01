# Proxmox And OMV Recovery Backups

## Host Recovery Bundle

Cloud-copy preparation and pending work: [Google Drive](GOOGLE-DRIVE.md).

`backup_host.py` is standalone, root-only and local to the Proxmox host. It does
not SSH to OMV or stop/restart any VM, container, VPN, Monit, APC or pve-cluster.
It is a recovery bundle for reinstalling the host, NOT a bootable system image.

Install the current standalone helpers on Proxmox in `/usr/local/sbin`, owned
by root with mode 0750. `/root` is only a transfer/staging location, not their
runtime location. After transferring all three current files to /root:

```bash
install -o root -g root -m 750 /root/backup_omv.py /root/backup_host.py /root/upload_gdrive.py /usr/local/sbin/
```

Run the host helper from its installed location:

```bash
python3 /usr/local/sbin/backup_host.py
python3 /usr/local/sbin/backup_host.py --run
```

The first command only checks prerequisites. The second rechecks them under an
exclusive lock and creates a root-private timestamped folder under
`/mnt/proxmox-backups/host-config/`. It requires the known independent HDD UUID,
at least 10 GiB free, mounted pmxcfs, a standalone node (no corosync config),
the reviewed persistent WG/SSH state and exactly the two running host containers.
Changed Docker mounts, queue location, missing state or extra running containers
stop the preflight instead of silently omitting data. Inspect/review differences
before adapting it; never weaken a failed guard without understanding the host.

Contents:
- `host-files.tar.gz`: /etc except pmxcfs, /usr/local, /opt/proxmox-vpn-gateway,
  root SSH/backup secrets/selected shell configuration and /var/spool/cron.
  Numeric ownership, ACLs and xattrs are retained. /etc includes Monit, UPS,
  network, firewall, systemd and AppArmor configuration and the private notifier env.
- `pmxcfs-config.db`: consistent SQLite backup of the live cluster filesystem DB,
  including VM/storage/user/key configuration normally presented under /etc/pve.
  The host is not stopped and the live DB is never replaced or written by this tool.
- `docker-images.tar.gz`: exact image IDs of vpn-gateway and monit-telegram;
  private inspect JSON preserves names, tags, environment, mounts and runtime flags.
- `vpn-gateway-rootfs.tar.gz` and `monit-telegram-rootfs.tar.gz`: live rootfs
  exports include writable-layer changes but exclude mounted volume contents.
  These are not atomic snapshots across running processes/files. Do not change
  host/container configuration during backup. They complement images and mounts,
  not replace runtime metadata or a recovery test.
- `telegram-queue.sqlite3`: SQLite backup API snapshot of the live mounted queue,
  including committed WAL data. The queue remains active. Restoring it can replay
  pending notifications; review before recovery. The host resolves the reviewed
  local Docker volume mountpoint and opens its database read-only; it does not
  use Python or serialize() inside the container. Non-local/option-backed volumes
  and symlink/missing queue databases stop preflight. The snapshot timeout is 60s.
- Package/storage/network/VM inventory, Docker diffs, a copy of the helper and
  `RESTORE.txt` describing recovery order and important safety restrictions.

The bundle does NOT include VM disks, data HDD contents, migration archive trees,
old-system SSD or the entire Docker storage directory. VM/app backups are separate.
Host snapshots may record a live VM backup lock; review VM locks and physical disk
mappings on an isolated replacement before attempting any startup.

Each gzip/tar and SQLite snapshot is validated before SHA256SUMS and COMPLETE
are written. Only then is the .partial directory renamed to its final name.
Failure retains private diagnostics and partial data without touching existing
backups. No pruning, automatic retry, schedule or offsite upload is configured.

**Contains unencrypted credentials and private keys.** Directories are root 0700,
files 0600. Do not paste inspect/inventory/log/archive contents into chat. Do not
copy to unencrypted removable storage or a public share. A separate encrypted
off-host copy is still required; OMV's rclone container does not see this HDD.

Verify later from inside the completed folder with `sha256sum -c SHA256SUMS`.
Recovery must follow RESTORE.txt on a replacement with nothing running, not by
blindly extracting /etc on the live host. Never run duplicate WireGuard identities
or a VM test with production raw HDDs attached. The helper has local tests; its
first successful target run was confirmed on 2026-11-01 at 14:55 MSK:
`proxmox-host-20261101T115531Z`. All archive and SQLite checks passed. A separate
checksum re-read and encrypted Google Drive copy subsequently passed through
upload_gdrive.py on 2026-11-01. Actual recovery testing remains pending.

The first target attempt on 2026-11-01 stopped at the queue snapshot because the
imported notifier SQLite library lacked serialize(). No service was stopped.
The helper was changed to host-side volume snapshots; rerun the updated standalone
file to create a new bundle. Keep the prior .partial folder until success is
verified; it is not a completed backup and is not resumed or deleted automatically.

Reference: https://github.com/proxmox/pve-docs/blob/master/pmxcfs.adoc

## Scheduled Chain

`proxmox-backups.cron` is an /etc/cron.d template, not a root crontab snippet:
it contains the required root username field. Install it ONLY on Proxmox after
all three /usr/local/sbin helpers have passed their manual runs. Do not duplicate these
jobs in crontab -e. Preserve/review any existing target file before replacement.

The host timezone must be Europe/Moscow. At 04:00 on Monday-Saturday, run the
host bundle then cloud upload. On Sunday at 04:00, first run VM 100's live snapshot
backup, then host bundle, then cloud upload. OMV is NOT shut down; the guest agent
may briefly freeze filesystem writes for consistency. The host VPN stays running.
The chain uses && so a failed
step stops subsequent steps. A common flock prevents overlap between scheduled
chains; a skipped locked invocation does not retry automatically. Each helper
also retains its own lock/preflight protections.

Create /var/log/proxmox-backup.log root:root 0600 and redirect chain output there.
Detailed host/upload diagnostics remain in their protected bundle/log paths.
Cron does not send Telegram failure alerts automatically; monitor these jobs and
verify the first actual scheduled execution separately. The template is prepared
locally; deployment is not confirmed until the user installs it.

The updated template calls upload_gdrive.py --run --prune. This rotates recognized
local/cloud generations to two per VM and two host bundles, only after replacements
are verified. Protected/unknown/incomplete copies are retained; see GOOGLE-DRIVE.md
for preview, safety rules and failure behavior. Monitor disk/cloud space.
This schedule does not replace Nextcloud logical
backups or restore tests, and its start time does not guarantee the OMV 03:00
cloud-copy job has completed; both may share network bandwidth.

## OMV VM Backup

Run `backup_omv.py` locally as root on Proxmox. With no arguments it only
performs checks; `--run` repeats those checks and invokes vzdump for VM 100
in live snapshot mode, with zstd compression and --remove 0 (no pruning).

The strict initial inventory is the 80G scsi0 volume on local-lvm and three
physical by-id HDDs on scsi1..3, each explicitly backup=0. The expected directory
storage must be mounted from the ProxmoxBackups UUID, contain backup content,
and have at least 90 GiB free. Unexpected disks, locks, an unavailable guest
agent or changed storage stop the script before invoking vzdump.

Run from a persistent Proxmox session, preferably tmux, not from OMV SSH.
OMV remains running: vzdump uses snapshot mode, NOT stop or suspend. With the
enabled guest agent, filesystem writes may briefly freeze/thaw; this is not a
VM shutdown and does not guarantee application-level consistency across excluded
HDDs. Separate database/application backups remain necessary. Host VPN is not stopped.
The script reports backup failure and guest status but does not force-start a
stopped or failed guest, remove locks, delete backups or alter storage settings.

The VM archive includes its configuration, system disk and Docker data actually
on that disk (including Nextcloud named volumes and OpenClaw's writable layer).
It does not back up the passed-through Data/UserData/Backups disks or their
Vaultwarden/GitLab bind mounts. Existing file backups and separate application
database/configuration backups remain necessary. Proxmox configuration and
host Docker gateways/keys are also outside this VM backup.

After successful vzdump, inspect the resulting archive and VM state, verify
compression and VMA integrity, and plan an isolated restore test. Never boot
a test restore with production raw disks attached or a duplicate LAN identity.
Do not delete the old system SSD or migration bundles before recovery is tested.
No backup schedule or retention policy is configured by this first-run helper.

The backup contains passwords, SSH keys and other secrets. Keep storage private
and use encrypted copies for off-host transport. The user reported a successful
first vzdump archive (2026-11-01 13:08 MSK) and VM running afterwards. zstd/VMA
verification subsequently passed through upload_gdrive.py, followed by successful
encrypted Google Drive upload and cryptcheck on 2026-11-01. An isolated restore
test is not yet confirmed. Local tests cover preflight policy only.

Reference: https://github.com/proxmox/pve-docs/blob/master/vzdump.adoc
