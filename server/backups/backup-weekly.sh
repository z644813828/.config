#!/bin/bash
set -euo pipefail

SRC="/srv/dev-disk-by-label-Data"
DST="/srv/dev-disk-by-label-ColdBackup"
DEV="/dev/disk/by-label/ColdBackup"
LOCK="/run/backup-weekly-cold.lock"
IN_PROGRESS="/run/backup-weekly-cold.in-progress"

exec 9>"$LOCK"
flock -n 9 || {
    echo "$(date): weekly cold backup already running"
    exit 1
}

# Monit не должен ожидать standby от ColdBackup во время штатной записи.
: > "$IN_PROGRESS"
trap 'rm -f "$IN_PROGRESS"' EXIT

if ! mountpoint -q "$SRC"; then
    echo "$(date): ERROR: $SRC is not mounted"
    exit 2
fi

mkdir -p "$DST"

if ! mountpoint -q "$DST"; then
    # Монтирование обращается к диску и автоматически выводит его из standby.
    mount "$DEV" "$DST"
fi

echo "=== weekly cold backup started $(date) ==="

rsync -aHAX --numeric-ids --delete --info=progress2 \
    "$SRC/TimeMachine" \
    "$DST"/

date > "$DST/.last_success"

echo "--- sizes ---"
du -sh "$DST"/*
df -h "$DST"

sync
umount "$DST"

# hdparm должен работать с диском, а не с его разделом (/dev/sde1).
DRIVE="/dev/$(lsblk -ndo PKNAME "$DEV")"
/sbin/hdparm -Y "$DRIVE" || true

echo "=== weekly cold backup finished $(date) ==="
