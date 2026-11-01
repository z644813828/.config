#!/usr/bin/env bash
set -euo pipefail
umask 077

DATA="/srv/dev-disk-by-uuid-9c6424ec-3918-4b89-8eb5-043ecb0f5ebf"
BACKUPS="/srv/dev-disk-by-uuid-87c841a9-8d9a-4b8c-96aa-6ea6da074aad"
BACKUP_DIR="$BACKUPS/Data/docker/gitlab"
KEY_FILE="/root/.backup-secrets/docker-gitlab.key"
LOCK="/run/backup-gitlab.lock"
DATE="$(date +%F-%H%M%S)"
WORK_DIR=""
ARCHIVE="${BACKUP_DIR}/gitlab-${DATE}.tar.gz"
ENCRYPTED="${ARCHIVE}.enc"

cleanup() {
  if [ -n "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
    rm -f "$ARCHIVE" "$ENCRYPTED.part"
  fi
}
trap cleanup EXIT

exec 9>"$LOCK"
flock -n 9 || {
  echo "$(date): GitLab backup already running"
  exit 1
}

for path in "$DATA" "$BACKUPS"; do
  mountpoint -q "$path" || { echo "ERROR: required HDD is not mounted" >&2; exit 2; }
done

# Follow the RUNNING deployment, not the preserved old gitlab directory.
APP_DIR=$(docker inspect -f '{{json .Mounts}}' gitlab | python3 -c '
import json, pathlib, sys
mounts = json.load(sys.stdin)
paths = {}
for m in mounts:
    if m["Destination"] in ("/etc/gitlab", "/var/opt/gitlab"):
        if m.get("Type") != "bind":
            raise SystemExit("STOP: GitLab must use reviewed bind mounts")
        paths[m["Destination"]] = pathlib.Path(m["Source"]).resolve()
data = pathlib.Path(sys.argv[1]).resolve()
config = paths.get("/etc/gitlab")
app = config.parent if config else None
if (not app or not app.is_relative_to(data) or config.name != "config"
        or paths.get("/var/opt/gitlab") != app / "data"
        or not (app / "docker-compose.yml").is_file()):
    raise SystemExit("STOP: unexpected GitLab deployment paths")
print(app)
' "$DATA")

if [ ! -s "$KEY_FILE" ]; then
  echo "$(date): ERROR: encryption key is missing: $KEY_FILE" >&2
  exit 2
fi

cd "$APP_DIR"
for path in "$ENCRYPTED" "$ARCHIVE" "$ENCRYPTED.part"; do
  test ! -e "$path" || { echo "ERROR: output archive already exists" >&2; exit 2; }
done
mkdir -p "$BACKUP_DIR"
WORK_DIR=$(mktemp -d "$BACKUP_DIR/tmp-$DATE.XXXXXX")
touch "$WORK_DIR/.started"

# Создаёт согласованный архив БД, репозиториев, LFS, артефактов и загрузок.
docker exec gitlab gitlab-backup create

GITLAB_BACKUP="$(find "$APP_DIR/data/backups" -maxdepth 1 -type f -name '*_gitlab_backup.tar' -newer "$WORK_DIR/.started" -printf '%T@ %p\n' | sort -nr | sed -n '1p' | cut -d' ' -f2-)"
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
  -out "$ENCRYPTED.part" \
  -pass "file:${KEY_FILE}"
mv "$ENCRYPTED.part" "$ENCRYPTED"

find "$BACKUP_DIR" -name 'gitlab-*.tar.gz.enc' -type f -mtime +30 -delete

# decrypt:
# openssl enc -d -aes-256-cbc -md sha256 -salt \
#   -in gitlab-YYYY-MM-DD-HHMMSS.tar.gz.enc \
#   -out gitlab-YYYY-MM-DD-HHMMSS.tar.gz \
#   -pass file:backup.key
