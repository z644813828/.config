#!/bin/bash
set -euo pipefail

MOUNT="${MACBOOK_BACKUP_MOUNT:-/srv/dev-disk-by-uuid-eb9e73fb-a8b9-4216-829e-7469929e5c31}"
FILE="${MACBOOK_BACKUP_STAMP:-$MOUNT/dmitriy/Документы/backup/date}"

if ! mountpoint -q "$MOUNT"; then
    echo "ERROR: UserData is not mounted: $MOUNT"
    exit 2
fi

# No check is required before the 3rd day of the month
if [ "$(date +%d)" -lt 3 ]; then
    echo "OK: monthly backup grace period (days 1-2)"
    exit 0
fi

if [ ! -s "$FILE" ]; then
    echo "ERROR: Backup has not been performed this month" >&2
    exit 1
fi

if [ "$(stat -c %s "$FILE")" -gt 4096 ]; then
    echo "ERROR: backup date file is unexpectedly large"
    exit 2
fi

stamp=$(cat "$FILE")
backup_epoch=$(date -d "$stamp" +%s 2>/dev/null) || {
    echo "ERROR: Invalid date in $FILE" >&2
    exit 1
}

if [ "$backup_epoch" -gt "$(date +%s)" ]; then
    echo "ERROR: backup date is in the future"
    exit 1
fi

file_month=$(date -d "$stamp" +%Y-%m)
if [ "$file_month" != "$(date +%Y-%m)" ]; then
    echo "ERROR: Backup has not been performed this month" >&2
    exit 1
fi
echo "OK: MacBook ZIP backup completed this month: $file_month"
