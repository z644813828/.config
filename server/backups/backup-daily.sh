#!/bin/bash
set -euo pipefail

BACKUP_MOUNT="/srv/dev-disk-by-label-Backups"
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/backup-daily.log"
STAMP_DIR="$BACKUP_MOUNT/.backup-status"
LOCK="/run/backup-rsync.lock"

exec 9>"$LOCK"
flock -n 9 || {
    echo "$(date): backup already running"
    exit 1
}

if ! mountpoint -q "$BACKUP_MOUNT"; then
    echo "$(date): ERROR: $BACKUP_MOUNT is not mounted"
    exit 2
fi

mkdir -p "$BACKUP_MOUNT/UserData"
mkdir -p "$BACKUP_MOUNT/Data/Software"
mkdir -p "$STAMP_DIR"

{
    echo
    echo "=== backup started $(date) ==="

    echo "--- UserData ---"
    rsync -aHAX --numeric-ids --delete --info=progress2 \
        /srv/dev-disk-by-label-UserData/ \
        /srv/dev-disk-by-label-Backups/UserData/

    echo "--- Data/Software ---"
    rsync -aHAX --numeric-ids --delete --info=progress2 \
        /srv/dev-disk-by-label-Data/Software/ \
        /srv/dev-disk-by-label-Backups/Data/Software/

    date > "$STAMP_DIR/backup.last_success"

    echo "--- sizes ---"
    du -sh "$BACKUP_MOUNT/UserData" "$BACKUP_MOUNT/Data/Software"
    df -h "$BACKUP_MOUNT"

    echo "=== backup finished $(date) ==="
} >> "$LOG_FILE" 2>&1
