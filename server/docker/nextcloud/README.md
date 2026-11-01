# Nextcloud Files on OMV

Fresh installation selected on 2026-11-01, replacing the abandoned Quantum
experiment. This compose file does NOT mount existing user directories.

## Deployment

Replace `server.example.invalid` in the compose and nginx templates with the
deployment hostname. This placeholder must not be applied to a running server.

Use a new directory on the mounted Data disk:

`/srv/dev-disk-by-uuid-9c6424ec-3918-4b89-8eb5-043ecb0f5ebf/docker/compose/nextcloud`

Create it only after verifying the Data mount and checking for name conflicts.
Do not reuse Vaultwarden's PostgreSQL service or its data. PostgreSQL and Redis
have no published host ports and use this project's separate Docker network.
Nextcloud's HTTP port is bound to localhost 8081 only; host nginx will provide
HTTPS 8880 with the existing certificate in a later step.

Create root-owned `secrets/` with mode 0700. Generate distinct random passwords
for `db_password` and `admin_password`, then give the files group 33 and mode
0640 so container `www-data` can read them. Keep the parent directory root-only.
Never print these secrets in chat or commit them. The bootstrap admin name is
`cloudadmin`, separate from normal personal accounts.

Nextcloud 34.0.5 Apache is pinned from the production image track checked on
2026-11-01. PostgreSQL is constrained to major 17 and Redis to minor 7.4; record
actual image IDs on deployment. Check the upstream release and security status
before reusing this file at a later date. The cron image must match the app.

Run `docker compose config --quiet`, pull the images and start the stack.
Allow several minutes for first installation, then verify using:

```bash
docker compose ps
docker exec --user www-data nextcloud php occ status
```

Do not expose nginx until the admin can log in, proxy settings are verified,
and unnecessary apps are reviewed. Read the app's actual Docker gateway and
configure only that IP as a trusted proxy; do not trust all RFC1918 networks.
The nginx frontend must overwrite client forwarding headers. Configure cron
mode with `php occ background:cron` and verify actual job execution.

The target reported successful first installation with Nextcloud 34.0.5 Apache
and PostgreSQL healthy. The initial `occ` missing-file error occurred while
the image was still copying into the new volume; it is not a reason to delete
volumes or reinstall. Apache's missing global ServerName warning is nonfatal.
The host frontend template is `../../nginx/nextcloud`. Before enabling it, set
Nextcloud's `trusted_proxies` to the gateway from its sole Docker network,
enable `files_external`, and select cron mode. Verify HTTPS using `curl --resolve`
to localhost with normal certificate verification. Never paste the bootstrap
password in chat; read the protected admin secret locally and change it on login.

## Existing Files And Permissions

The named volumes `nextcloud_html`, `nextcloud_data`, `nextcloud_db` live on the
OMV system disk (Docker storage). The `data` volume is Nextcloud's own home area,
previews, app data and temporary upload storage, NOT the existing UserData HDD.
Monitor its free space and limit ordinary home quotas. Never promise that all
uploads go to UserData: users must upload inside the external mounted folder.

### System-Disk Home Quotas

Run `python3 set-home-quotas.py` as root on OMV to set a 1 GB home quota for
existing accounts (including cloudadmin) and the default for future accounts.
The script explicitly excludes external mounts from quota accounting and reads
back each account setting. It requires the running `nextcloud` container.
It does not delete existing files or move data. Nextcloud account quotas are
not filesystem limits: previews, logs, database, temporary files, trash and
versions can still consume additional system-disk space.

After initial installation, mount only explicitly selected existing user
directories outside `/var/www/html`, initially read-only. Use External Storage
with per-user availability, and enable sharing only on intended mounts.
Never recursively chown existing data to UID 33, and never expose an unscoped
UserData root to every account. Resolve filesystem access using reviewed ACLs
or an appropriate storage backend, preserving Samba permissions and backup
numeric ownership. Linux/Samba passwords are not automatically Nextcloud users.

Enable detection of external modifications and schedule appropriate scans for
Samba-side changes. Test access isolation, uploads and public link behavior
before enabling writes. Do not import the old File Browser database or shares.

## Recovery

Keep the original `/root/filebrowser-migration.tar.gz` and read-only old SSD.
Nextcloud needs a consistent PostgreSQL backup plus config, application/data
volumes and protected secrets. A VM system-disk backup covers the named-volume
bytes, but requires appropriate consistency; separate logical backups and a
restore test are still needed. Existing HDD files retain their own data backup
policy. Do not use `docker compose down -v` or global Docker prune for cleanup.

## Personal Folder Layout Automation

`configure-personal-storage.py` is an OMV-side CLI, not a remote deployment tool.
Usernames are required positional arguments, not a hardcoded account allowlist.
It does not connect over SSH, create accounts, edit Compose, modify ACLs, move
data, delete mounts, or touch guest/service accounts.

Prerequisites: the selected Nextcloud accounts, and all eight Russian-named personal
directories on UserData (including `Рабочий стол`, not `Рабочий`). Expose each
user root as an exact writable bind at `/external/USERNAME` to both app and cron;
expose the existing Software/OS and Software/_Software sources at /external/OS
and /external/_Software. Set reviewed read/write/search ACLs for UID 33 and
inheritable ACLs preserving access for each original owner. Never recursively
chown the existing data. andrey/ludmila need these steps too; their Linux
accounts alone do not create Nextcloud users or Docker mounts.

`grant-personal-access.py andrey ludmila` is a separate explicit ACL preparation
step, run as root on OMV. It validates the mounted UserData root and directory
owners, backs up numeric ACLs under a private /root directory, skips symlinks,
and never changes ownership. Before widening ACL masks for UID 33, it clamps
other named/group entries to their previous effective rights. Defaults grant
both UID 33 and the personal owner access to future files. Existing raw ACL
permissions may be normalized, but other principals' effective rights remain
unchanged. It does not modify OS home directories, shared Software or Docker.
Keep the backup for rollback with `setfacl --restore=/root/.../before.acl`.

Run `python3 configure-personal-storage.py USERNAME [USERNAME ...]` to display a plan. It checks existing
accounts/binds, container-side directory access, conflicting mounts and physical
files that would be hidden. It then validates its import with `occ --dry`.
Only `--apply` imports new mounts, with a root-private before/import snapshot.
Repeated runs skip matching mounts and stop on conflicting configurations.
Do not share the complete snapshots; other storage configurations may be private.

The user explicitly approved replacing primary-home folder views for all five
accounts. Use `--replace-root-folders` for both plan and apply to permit existing
primary-home directories (such as the auto-created Templates directory) to be
hidden by the new external mounts. It never deletes or moves their contents.
The root-private backup records all shadowed paths for recovery. Existing files,
symlinks, conflicting external mounts and occupied nested Software/OS paths still
block the operation. Do not clean hidden original directories before reviewing
their contents and verifying backups; remove the new mount to access them again.

The layout has eight root-level personal mounts per user, plus nested
`Общедоступные/Software` and `Общедоступные/OS` mounts, each scoped to exactly one
user from creation. Nesting is configured through the Nextcloud 34 CLI import,
not ordinary filesystem symlinks. These entries appear in Nextcloud only; they
are not physical copies and do not add directories to an SMB share.
Current explicit Software/OS write grants are retained; newly granted access to
these shared sources is read-only. Review the plan before applying.

Legacy `Мои файлы`, OS and _Software mounts remain unchanged until the new layout
has been tested. Removing them can invalidate public links; no HDD file deletion
is required. Rescan the selected user folders after removing obsolete mounts.
The script cannot preserve the identity of shares when switching from old to
new external mount configurations; validate/recreate affected public links.

Tests: `python3 -m unittest discover -s server/docker/nextcloud -p test_personal_storage.py`.

## Add A New Personal User

Copy `add-user.py`, `configure-personal-storage.py` and `grant-personal-access.py`
together into a root-owned directory on OMV. Do not replace the live Compose file
with this repository's deployment template: the live one has real proxy settings,
secrets references and the existing users' mounts.

Run on OMV as root, from an interactive terminal:

```bash
python3 add-user.py newperson
python3 add-user.py newperson --apply
```

The first invocation is a plan, not a mutation. The second prompts twice for one
password used for OMV/Linux/Samba and Nextcloud. It is passed over stdin, never
in command arguments, Compose, checkpoints or a password file. Changes to either
password after creation are independent; there is no ongoing password sync.

The CLI creates a normal OMV-managed user through UserMgmt RPC (not raw useradd),
without admin/sudo groups or SSH keys. It creates `/home/USERNAME`, a private HDD
root and eight personal directories, with home symlinks and reviewed UID 33 ACLs.
The desktop directory is `Рабочий стол`. New Nextcloud users are non-admin, have
a 1 GB internal-home quota and ten per-user external mounts. New shared OS and
Software access is read-only; existing explicit write grants are retained.
Template home directories may be hidden by the external mounts but are not
deleted. No new SMB share is published automatically.

The CLI requires the live UserData/Data mountpoints, disabled global OMV home
relocation, a working Nextcloud installation, shared mounts, and external-storage
quota exclusion already set to false. It checks the daily backup script for a
UserData rsync source and checks root's crontab for that script. Include/exclude,
filter and files-from options do NOT block provisioning: they cause a warning to
manually verify coverage of the new user's HDD root. No claim of full coverage is
made just because a source and cron entry exist. New folders are inside UserData,
but filters can exclude them; review those rules and nightly results separately.
This does not prove the backup ran or reached Google Drive. Unsupported source layouts stop the
preflight instead of guessing. Use `--backup-script PATH` for the reviewed live
script if its location differs.

To persist new per-user Docker binds without rewriting YAML or private settings,
the CLI writes `compose.personal-binds.json` alongside the live Compose file.
It recreates ONLY app and cron, causing brief Nextcloud downtime. Other services
and existing base-file mounts are retained. All future Compose operations must
include both files, or new binds will disappear on container recreation:

```bash
docker compose -f docker-compose.yml -f compose.personal-binds.json up -d
```

Do not run the creation CLI with a name already belonging to an account or HDD
folder. It refuses to adopt them or reset passwords. On a partial failure, correct
the cause then use `python3 add-user.py newperson --resume --apply`. Root-private
checkpoints and bind backups are in `/var/lib/omv-personal-users`; ACL backups are
under `/root/nextcloud-acl-*`. It never automatically deletes users/data or rolls
back successfully completed stages. Resume never resets existing passwords; if
only the Nextcloud account is still missing, enter the same password again.
After success, test login, create/upload, access isolation and link sharing.

Tests: `python3 -B -m unittest discover -s server/docker/nextcloud -p 'test_*.py'`.
Local unit tests do not replace an end-to-end run on the actual OMV installation.

OMV API reference: https://github.com/openmediavault/openmediavault/blob/master/deb/openmediavault/usr/share/openmediavault/engined/rpc/usermgmt.inc

## References

- https://hub.docker.com/_/nextcloud
- https://github.com/nextcloud/docker#docker-secrets
- https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/external_storage/local.html
- https://docs.nextcloud.com/server/stable/admin_manual/configuration_files/external_storage_configuration_gui.html
