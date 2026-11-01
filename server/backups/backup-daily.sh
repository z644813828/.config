#!/bin/bash
set -euo pipefail

BACKUP_MOUNT="/srv/dev-disk-by-uuid-87c841a9-8d9a-4b8c-96aa-6ea6da074aad"
USERDATA="/srv/dev-disk-by-uuid-eb9e73fb-a8b9-4216-829e-7469929e5c31"
DATA="/srv/dev-disk-by-uuid-9c6424ec-3918-4b89-8eb5-043ecb0f5ebf"
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/backup-daily.log"
STAMP_DIR="$BACKUP_MOUNT/.backup-status"
LOCK="/run/backup-rsync.lock"

exec 9>"$LOCK"
flock -n 9 || {
    echo "$(date): backup already running"
    exit 1
}

# Check BOTH sources before --delete, not only the destination.
for path in "$USERDATA" "$DATA" "$BACKUP_MOUNT"; do
    if ! mountpoint -q "$path"; then
        echo "$(date): ERROR: $path is not mounted"
        exit 2
    fi
done
if [ ! -d "$DATA/Software" ]; then
    echo "$(date): ERROR: source Software directory is missing"
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
        --exclude='/dmitriy/Документы/backup/' \
        "$USERDATA/" \
        "$BACKUP_MOUNT/UserData/"

    echo "--- Data/Software ---"
    rsync -aHAX --numeric-ids --delete --info=progress2 \
        "$DATA/Software/" \
        "$BACKUP_MOUNT/Data/Software/"

    echo "--- sizes ---"
    du -sh "$BACKUP_MOUNT/UserData" "$BACKUP_MOUNT/Data/Software"
    df -h "$BACKUP_MOUNT"

    date > "$STAMP_DIR/backup.last_success.tmp"
    mv "$STAMP_DIR/backup.last_success.tmp" "$STAMP_DIR/backup.last_success"

    echo "=== backup finished $(date) ==="
} >> "$LOG_FILE" 2>&1
