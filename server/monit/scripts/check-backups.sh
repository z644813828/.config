#!/bin/bash
set -euo pipefail

BACKUP_MOUNT="/srv/dev-disk-by-label-Backups"
STAMP="$BACKUP_MOUNT/.backup-status/backup.last_success"
MAX_MINUTES=$((36 * 60))

if ! mountpoint -q "$BACKUP_MOUNT"; then
    echo "CRITICAL: $BACKUP_MOUNT is not mounted"
    exit 2
fi

if [ ! -f "$STAMP" ]; then
    echo "CRITICAL: backup stamp not found: $STAMP"
    exit 2
fi

if find "$STAMP" -mmin "-$MAX_MINUTES" | grep -q .; then
    echo "OK: backup is fresh: $(cat "$STAMP")"
    exit 0
fi

echo "CRITICAL: backup is older than 36 hours: $(cat "$STAMP")"
exit 2
