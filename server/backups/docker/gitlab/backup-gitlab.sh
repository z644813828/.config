#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/srv/dev-disk-by-label-Data/docker/compose/gitlab"
BACKUP_DIR="/srv/dev-disk-by-label-Backups/Data/docker/gitlab"
KEY_FILE="/root/.backup-secrets/docker-gitlab.key"
LOCK="/run/backup-gitlab.lock"
DATE="$(date +%F-%H%M%S)"
WORK_DIR="${BACKUP_DIR}/tmp-${DATE}"
ARCHIVE="${BACKUP_DIR}/gitlab-${DATE}.tar.gz"
ENCRYPTED="${ARCHIVE}.enc"

cleanup() {
  rm -rf "$WORK_DIR"
  rm -f "$ARCHIVE"
}
trap cleanup EXIT

exec 9>"$LOCK"
flock -n 9 || {
  echo "$(date): GitLab backup already running"
  exit 1
}

mkdir -p "$WORK_DIR" "$BACKUP_DIR"

if [ ! -f "$KEY_FILE" ]; then
  echo "$(date): ERROR: encryption key is missing: $KEY_FILE" >&2
  exit 2
fi

cd "$APP_DIR"

# Создаёт согласованный архив БД, репозиториев, LFS, артефактов и загрузок.
docker exec gitlab gitlab-backup create

GITLAB_BACKUP="$(find "$APP_DIR/data/backups" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)"
if [ -z "$GITLAB_BACKUP" ]; then
  echo "$(date): ERROR: GitLab backup archive was not created" >&2
  exit 3
fi

# config содержит gitlab-secrets.json, без которого восстановление неполное.
tar -czf "${WORK_DIR}/gitlab-config.tar.gz" -C "$APP_DIR" \
  docker-compose.yml config
cp -- "$GITLAB_BACKUP" "$WORK_DIR/"

tar -czf "$ARCHIVE" -C "$WORK_DIR" .

openssl enc -aes-256-cbc -md sha256 -salt \
  -in "$ARCHIVE" \
  -out "$ENCRYPTED" \
  -pass "file:${KEY_FILE}"

find "$BACKUP_DIR" -name 'gitlab-*.tar.gz.enc' -type f -mtime +30 -delete

# decrypt:
# openssl enc -d -aes-256-cbc -md sha256 -salt \
#   -in gitlab-YYYY-MM-DD-HHMMSS.tar.gz.enc \
#   -out gitlab-YYYY-MM-DD-HHMMSS.tar.gz \
#   -pass file:backup.key
