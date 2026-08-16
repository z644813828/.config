#!/usr/bin/env bash
set -euo pipefail

SOURCE=/backup
DESTINATION=gdrive_crypt:offsite-backups
WORKSPACE=/workspace
LOG_DIR="$WORKSPACE/logs"
LOCK_FILE="$WORKSPACE/.backup-to-gdrive.lock"
BWLIMIT="${RCLONE_BWLIMIT:-10M}"

timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
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

log_file="$LOG_DIR/rclone-copy-$(date -u '+%Y%m%dT%H%M%SZ').log"
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

printf '[%s] Backup copy completed successfully\n' "$(timestamp)" | tee -a "$log_file"
