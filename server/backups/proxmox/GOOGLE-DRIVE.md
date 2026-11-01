# Proxmox Backups To Google Drive

First upload succeeded on the target on 2026-11-01. The user selected Google Drive, NOT
ColdBackup. No changes to the ColdBackup disk or old weekly job are requested.

Confirmed uploaded and cryptchecked generations:
- vm/100/2026_11_01-13_08_16 (local zstd/VMA validation also passed).
- host/proxmox-host-20261101T115531Z (local host SHA-256 validation also passed).

Both generations received OK from the helper. The private target log is
/var/log/proxmox-gdrive/20261101T131248Z.log. This confirms the encrypted upload
and checksum comparison, NOT a downloaded recovery/boot test. Scheduling and
rotation templates have since been prepared; target installation is not confirmed.

Use native rclone on Proxmox to read its own backup HDD. Do not expose the HDD
writable to OMV, mount the Docker socket there or replace OMV's existing job.
The existing OMV job still copies all of its Backups disk to
`gdrive_crypt:offsite-backups`.

Copy the CURRENT protected `/root/.backup-secrets/rclone/rclone.conf` from OMV
to a separate private `/root/.config/rclone/rclone.conf` on Proxmox. Refuse any
existing destination; use a root-only temporary directory for transfer and remove
that temporary copy afterwards. Directory 0700, file 0600. Do not print config,
tokens or crypt passwords. A separate writable config avoids simultaneous token
refresh writes between hosts. Keep an encrypted offline copy of this configuration
outside both servers; storing the only crypt key inside its own encrypted backup
is not a recovery strategy.

Install native rclone and test `rclone listremotes` and `rclone lsd gdrive_crypt:`.
Do not copy a stale configuration from the old SSD if the current OMV one works.
The user installed Debian rclone 1.60.1 and confirmed listremotes and an encrypted
directory listing from Proxmox on 2026-11-01. The initial SSH public-key failure
was followed by a successful user-managed transfer; no server authentication
changes are required by this workflow.

Intended NEW destination: `gdrive_crypt:proxmox-backups`, separate from the
existing offsite-backups tree. Upload only finished VM archives and completed
host bundles, excluding all .partial directories and the migration tree. Retain
two verified generations per VM and two completed host bundles; never prune
existing remote generations before a replacement is uploaded and checked.
The upload/verification helper is `upload_gdrive.py`; optional local/cloud rotation
is now available with --prune, and the cron template requests it after uploads.

## First Upload

Install the current standalone script as `/usr/local/sbin/upload_gdrive.py`
(root:root, mode 0750); /root is only a transfer/staging location. Then run:

```bash
python3 /usr/local/sbin/upload_gdrive.py
python3 /usr/local/sbin/upload_gdrive.py --run
```

Default mode displays the selected generations without network writes. It
requires the mounted backup HDD UUID, private root-owned rclone config and a crypt
remote. It selects at most two finished VM backups per VM ID (matching successful
vzdump logs) and two host directories with COMPLETE and SHA256SUMS. It does not
read the migration tree or incomplete .partial directories.

Run mode uses a private temporary hardlink view on the SAME backup disk, without
copying huge archives or modifying their contents/permissions. It verifies local
VMA/zstd or host SHA-256 before upload, adds a VM manifest, runs `rclone copy` and
then `rclone cryptcheck --one-way` against the encrypted destination. It rejects
source metadata changes during transfer. rclone cryptcheck compares encrypted
checksums using the underlying Drive hash; ordinary size-only comparison is not
treated as successful verification. The installed rclone 1.60.1 supports it.

Each cloud generation gets UPLOAD-COMPLETE.json ONLY after cryptcheck succeeds.
A copied host COMPLETE file is not a cloud verification marker. Repeat runs
recheck a matching committed generation without overwriting it; changed manifests
or marker/network errors stop instead of assuming the destination is empty.
Interrupted uncommitted uploads can be retried. An upload failure removes only
temporary hardlinks and never reaches rotation. A cleanup failure can leave a
partially removed old generation; the two verified replacements remain intact.

Only encrypted destinations below `gdrive_crypt:proxmox-backups` are used;
OMV's offsite-backups tree is untouched. Bandwidth is limited to 10 MiB/s.
Progress/diagnostics go to private /var/log/proxmox-gdrive timestamped logs; do
not post raw logs/config to chat. Console output identifies stages and generations.

## Two-Generation Rotation

Deploy the updated helper, then preview with NO upload/deletion:

```bash
python3 /usr/local/sbin/upload_gdrive.py --prune
```

Apply by uploading/rechecking replacements first, then pruning:

```bash
python3 /usr/local/sbin/upload_gdrive.py --run --prune
```

Plain --run still does not delete. The updated proxmox-backups.cron uses
--run --prune; install the updated template to enable scheduled cleanup.

For each VM ID and for host bundles, keep two completed local generations and
two corresponding verified cloud generations. If fewer than two replacements
exist, cloud commit markers are missing, the current run did not verify them,
or cloud has newer generations absent locally, cleanup is skipped or stopped.
Any upload/cryptcheck failure stops before cleanup. A local backup completed
during upload is never deleted just because it was not in the initial selection.

Only recognized older generations are candidates. Local VM archives marked
protected in Proxmox are retained in both places while present in its inventory;
cloud markers can also carry protected=true. Protected copies may exceed two.
Local VM deletion uses pvesm free (native protection enforced); its recorded log
is removed afterwards. Notes/unknown sidecars are not manually deleted. Host
folders must have an exact valid SHA-256 manifest; only those recorded files
are unlinked, not a recursively removed arbitrary directory.

Remote cleanup is restricted to this helper's proxmox-backups prefix and valid
UPLOAD-COMPLETE markers. The old SHA256SUMS must match its verified marker.
Only manifest-listed files plus this helper's metadata are deleted, followed by
rmdir; extra/unrecognized files are never purged. The old upload marker is removed
first so interrupted cleanup cannot advertise an incomplete generation as valid.
An interruption can leave uncommitted residual files requiring manual inspection;
it cannot roll back already deleted old files. A root-private .rotation.json
journal beside the run log records the plan before any deletion. Local deletion
starts only after planned cloud cleanup succeeds. New replacements are rechecked
before applying the plan. Old SSD, migration data, .partial/uncommitted generations,
unrecognized names and OMV offsite-backups are never rotation candidates.

Rotation tests use mocked remote/native-storage commands and temporary local
fixtures; actual Drive deletion still requires the first reviewed target run.
This is not a substitute for a downloaded recovery/boot test.

Preserve the crypt config separately offline. It was copied to Proxmox AFTER the
first host bundle was created; the existing bundle does not yet contain this new
root/.config/rclone/rclone.conf. A future host backup includes it, but recovering
an encrypted cloud bundle still requires the crypt key from outside that bundle.

Tests: python3 -B -m unittest discover -s server/backups/proxmox -p 'test_*.py'.
Remote verification source: https://github.com/rclone/rclone/blob/v1.60.1/docs/content/commands/rclone_cryptcheck.md

Reported source sizes on 2026-11-01: VM dump 9.3 GiB, host-config tree 1.3 GiB
(including incomplete attempts); only one finished OMV VM archive exists so far.
These are observed disk-use figures, not exact upload-volume estimates.
