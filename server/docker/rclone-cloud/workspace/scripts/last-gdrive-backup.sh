#!/usr/bin/env bash
set -euo pipefail

STATUS_REMOTE=gdrive_backups:rclone/date.txt
MAX_ATTEMPTS=3
RETRY_DELAY_SECONDS=5

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if value="$(rclone cat "$STATUS_REMOTE" \
      --retries 1 \
      --low-level-retries 1 \
      --contimeout 10s \
      --timeout 15s 2>/dev/null)"; then
    value="$(printf '%s' "$value" | tr -d '\r\n')"

    if [ -n "$value" ] && date -d "$value" '+%Y-%m-%dT%H:%M:%S%:z' >/dev/null 2>&1; then
      TZ=Europe/Moscow date -d "$value" '+%Y-%m-%dT%H:%M:%S%:z'
      exit 0
    fi
  fi

  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    sleep "$RETRY_DELAY_SECONDS"
  fi
done

echo "Backup status file is unavailable, empty, or invalid after ${MAX_ATTEMPTS} attempts: $STATUS_REMOTE" >&2
exit 1
