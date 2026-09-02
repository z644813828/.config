#!/usr/bin/env bash
set -euo pipefail

SOURCE=/backup
DESTINATION=gdrive_crypt:offsite-backups
STATUS_REMOTE=gdrive_backups:rclone/date.txt
WORKSPACE=/workspace
LOG_DIR="$WORKSPACE/logs"
LOCK_FILE="$WORKSPACE/.backup-to-gdrive.lock"
BWLIMIT="${RCLONE_BWLIMIT:-10M}"

timestamp() {
  date '+%Y-%m-%dT%H:%M:%S%:z'
}

fail() {
  printf '[%s] ERROR: %s\n' "$(timestamp)" "$*" >&2
  exit 1
}

findmnt -T "$SOURCE" >/dev/null 2>&1 || fail "$SOURCE is not a mount point"

mount_options="$(findmnt -no OPTIONS -T "$SOURCE")"
case ",$mount_options," in
  *,ro,*) ;;
  *) fail "$SOURCE must be mounted read-only" ;;
esac

find "$SOURCE" -mindepth 1 -print -quit | grep -q . || fail "$SOURCE is unexpectedly empty"

mkdir -p "$LOG_DIR"
exec 9>"$LOCK_FILE"
flock -n 9 || fail "another backup process is already running"

log_file="$LOG_DIR/rclone-copy-$(date '+%Y%m%dT%H%M%S%z').log"
printf '[%s] Starting copy from %s to %s (bwlimit=%s)\n' \
  "$(timestamp)" "$SOURCE" "$DESTINATION" "$BWLIMIT" | tee -a "$log_file"

rclone copy "$SOURCE" "$DESTINATION" \
  --fast-list \
  --checkers 8 \
  --transfers 4 \
  --retries 3 \
  --low-level-retries 10 \
  --bwlimit "$BWLIMIT" \
  --stats 1m \
  --stats-one-line \
  --log-file "$log_file" \
  --log-level INFO

completed_at="$(timestamp)"
printf '%s\n' "$completed_at" | rclone rcat "$STATUS_REMOTE" \
  --retries 3 \
  --low-level-retries 10

printf '[%s] Backup copy completed successfully; status written to %s\n' \
  "$completed_at" "$STATUS_REMOTE" | tee -a "$log_file"
