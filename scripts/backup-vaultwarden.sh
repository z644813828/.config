#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/srv/dev-disk-by-label-Data/docker/compose/vaultwarden"
BACKUP_DIR="/srv/dev-disk-by-label-UserData/__backups/vaultwarden"
KEY_FILE="${BACKUP_DIR}/backup.key"
DATE="$(date +%F-%H%M%S)"
WORK_DIR="${BACKUP_DIR}/tmp-${DATE}"
ARCHIVE="${BACKUP_DIR}/vaultwarden-${DATE}.tar.gz"
ENCRYPTED="${ARCHIVE}.enc"

cleanup() {
  rm -rf "$WORK_DIR"
  rm -f "$ARCHIVE"
}
trap cleanup EXIT

mkdir -p "$WORK_DIR" "$BACKUP_DIR"

cd "$APP_DIR"

docker exec vaultwarden-postgres pg_dump -U vaultwarden -d vaultwarden -Fc > "${WORK_DIR}/postgres.dump"

BACKUP_PATHS=(
  "vw-data/attachments"
  "vw-data/config.json"
  "docker-compose.yml"
)

if [ -d "vw-data/sends" ]; then
  BACKUP_PATHS+=("vw-data/sends")
fi

if compgen -G "vw-data/rsa_key*" > /dev/null; then
  BACKUP_PATHS+=("vw-data/rsa_key"*)
fi

tar -czf "${WORK_DIR}/vw-data.tar.gz" "${BACKUP_PATHS[@]}"

tar -czf "$ARCHIVE" -C "$WORK_DIR" .

openssl enc -aes-256-cbc -md sha256 -salt \
  -in "$ARCHIVE" \
  -out "$ENCRYPTED" \
  -pass "file:${KEY_FILE}"

find "$BACKUP_DIR" -name "vaultwarden-*.tar.gz.enc" -type f -mtime +30 -delete

#decrypt:
# openssl enc -d -aes-256-cbc -md sha256 -salt \
  # -in vaultwarden-YYYY-MM-DD-HHMMSS.tar.gz.enc \
  # -out vaultwarden-YYYY-MM-DD-HHMMSS.tar.gz \
  # -pass "file:backup.key"

