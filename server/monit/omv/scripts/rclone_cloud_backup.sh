#!/usr/bin/env bash
set -euo pipefail

CONTAINER=rclone-cloud
MAX_AGE_SECONDS=$((36 * 60 * 60))

docker inspect "$CONTAINER" >/dev/null 2>&1 || {
    echo "CRITICAL: container not found: $CONTAINER"
    exit 2
}

[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = "true" ] || {
    echo "CRITICAL: container is not running: $CONTAINER"
    exit 2
}

backup_time="$(docker exec "$CONTAINER" bash /workspace/scripts/last-gdrive-backup.sh)" || {
    echo "CRITICAL: cannot read Google Drive backup timestamp"
    exit 2
}

backup_epoch="$(date -u -d "$backup_time" +%s)" || {
    echo "CRITICAL: invalid Google Drive backup timestamp"
    exit 2
}

now_epoch="$(date -u +%s)"
age_seconds=$((now_epoch - backup_epoch))

if [ "$age_seconds" -lt 0 ] || [ "$age_seconds" -gt "$MAX_AGE_SECONDS" ]; then
    echo "CRITICAL: Google Drive backup is stale: $backup_time (${age_seconds}s old)"
    exit 2
fi

echo "OK: Google Drive backup is fresh: $backup_time (${age_seconds}s old)"
