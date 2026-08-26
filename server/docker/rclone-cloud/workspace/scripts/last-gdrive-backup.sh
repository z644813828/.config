#!/usr/bin/env bash
set -euo pipefail

STATUS_REMOTE=gdrive_backups:rclone/date.txt

value="$(rclone cat "$STATUS_REMOTE" | tr -d '\r\n')"
[ -n "$value" ] || {
  echo "Backup status file is empty: $STATUS_REMOTE" >&2
  exit 1
}

date -u -d "$value" '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1 || {
  echo "Backup status file has an invalid timestamp" >&2
  exit 1
}

printf '%s\n' "$value"
