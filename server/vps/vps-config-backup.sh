#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/root/.vps-config-backup.env}"
if [[ ! -r "$ENV_FILE" ]]; then
  echo "Missing env file: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${FTP_HOST:?FTP_HOST is required}"
: "${FTP_USER:?FTP_USER is required}"
: "${FTP_PASS:?FTP_PASS is required}"
: "${REMOTE_DIR:?REMOTE_DIR is required}"
: "${HOST_ID:?HOST_ID is required}"
export FTP_HOST FTP_USER FTP_PASS REMOTE_DIR

RETENTION_DAYS="${RETENTION_DAYS:-30}"
MAX_REMOTE_BYTES="${MAX_REMOTE_BYTES:-21474836480}" # 20 GiB safety cap for 25 GB FTP storage.
LOCAL_KEEP_DAYS="${LOCAL_KEEP_DAYS:-7}"

BACKUP_ROOT="${BACKUP_ROOT:-/var/backups/vps-config}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
NAME="vps-config-${HOST_ID}-${STAMP}"
STAGE="${BACKUP_ROOT}/${NAME}"
ARCHIVE="${BACKUP_ROOT}/${NAME}.tar.gz"

mkdir -p "$BACKUP_ROOT"
rm -rf "$STAGE"
mkdir -p "$STAGE"

copy_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
  fi
}

copy_glob_if_exists() {
  local dst_dir="$1"
  shift
  mkdir -p "$dst_dir"
  local item
  for item in "$@"; do
    if [[ -e "$item" ]]; then
      cp -a "$item" "$dst_dir/"
    fi
  done
}

mkdir -p "$STAGE/etc/x-ui"
if [[ -f /etc/x-ui/x-ui.db ]]; then
  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 /etc/x-ui/x-ui.db ".backup '$STAGE/etc/x-ui/x-ui.db'"
  else
    cp -a /etc/x-ui/x-ui.db "$STAGE/etc/x-ui/x-ui.db"
  fi
fi

copy_if_exists /usr/local/x-ui/bin/config.json "$STAGE/usr/local/x-ui/bin/config.json"
copy_if_exists /usr/local/x-ui/bin/README.md "$STAGE/usr/local/x-ui/bin/README.md"
copy_if_exists /usr/local/x-ui/bin/LICENSE "$STAGE/usr/local/x-ui/bin/LICENSE"

copy_if_exists /opt/mtproto-web/index.php "$STAGE/opt/mtproto-web/index.php"
copy_if_exists /opt/mtproto-web/.env "$STAGE/opt/mtproto-web/.env"
copy_if_exists /usr/local/bin/mtproto-traffic "$STAGE/usr/local/bin/mtproto-traffic"
copy_if_exists /root/cert "$STAGE/root/cert"

copy_glob_if_exists "$STAGE/etc/systemd/system" \
  /etc/systemd/system/mtg*.service \
  /etc/systemd/system/mtproto*.service \
  /etc/systemd/system/mtproto*.timer \
  /etc/systemd/system/mtproto*.path \
  /etc/systemd/system/x-ui.service

copy_glob_if_exists "$STAGE/etc/logrotate.d" \
  /etc/logrotate.d/x-ui* \
  /etc/logrotate.d/*xray* \
  /etc/logrotate.d/*mtproto*

{
  echo "created_utc=$STAMP"
  echo "host_id=$HOST_ID"
  hostnamectl 2>/dev/null || hostname || true
  echo
  echo "listening_ports:"
  ss -ltnup 2>/dev/null || true
  echo
  echo "x-ui:"
  systemctl is-active x-ui 2>/dev/null || true
  pgrep -a xray 2>/dev/null || true
  echo
  echo "mtproto_units:"
  systemctl list-units --type=service --type=timer --type=path --all --no-pager 2>/dev/null \
    | grep -Ei 'mtg|mtproto' || true
} > "$STAGE/manifest.txt"

tar -C "$STAGE" -czf "$ARCHIVE" .
rm -rf "$STAGE"

python3 - "$ARCHIVE" <<'PY'
import ftplib
import os
import posixpath
import sys
import time

archive = sys.argv[1]
ftp_host = os.environ["FTP_HOST"]
ftp_user = os.environ["FTP_USER"]
ftp_pass = os.environ["FTP_PASS"]
remote_dir = os.environ["REMOTE_DIR"]
retention_days = int(os.environ.get("RETENTION_DAYS", "30"))
max_remote_bytes = int(os.environ.get("MAX_REMOTE_BYTES", str(20 * 1024**3)))

def ensure_dir(ftp, path):
    ftp.cwd("/")
    current = ""
    for part in [p for p in path.strip("/").split("/") if p]:
        current = posixpath.join(current, part)
        try:
            ftp.mkd(part)
        except ftplib.error_perm as exc:
            if not str(exc).startswith("550"):
                raise
        ftp.cwd(part)

def list_backups(ftp):
    names = [name for name in ftp.nlst() if name.startswith("vps-config-") and name.endswith(".tar.gz")]
    items = []
    for name in names:
        size = 0
        try:
            size = int(ftp.size(name) or 0)
        except Exception:
            pass
        mtime = 0
        try:
            resp = ftp.sendcmd(f"MDTM {name}")
            if resp.startswith("213 "):
                mtime = time.mktime(time.strptime(resp[4:].strip(), "%Y%m%d%H%M%S"))
        except Exception:
            pass
        items.append({"name": name, "size": size, "mtime": mtime})
    # Filename contains UTC timestamp; use it as fallback sort key.
    items.sort(key=lambda x: (x["mtime"], x["name"]))
    return items

ftp = ftplib.FTP()
ftp.connect(ftp_host, 21, timeout=30)
ftp.login(ftp_user, ftp_pass)
ensure_dir(ftp, remote_dir)

remote_name = os.path.basename(archive)
with open(archive, "rb") as fh:
    ftp.storbinary(f"STOR {remote_name}", fh)
print(f"uploaded {remote_name} ({os.path.getsize(archive)} bytes)")

now = time.time()
items = list_backups(ftp)
for item in items:
    if item["mtime"] and now - item["mtime"] > retention_days * 86400:
        ftp.delete(item["name"])
        print(f"deleted old remote backup {item['name']}")

items = list_backups(ftp)
total = sum(item["size"] for item in items)
while total > max_remote_bytes and len(items) > 1:
    item = items.pop(0)
    ftp.delete(item["name"])
    total -= item["size"]
    print(f"deleted remote backup due to size cap {item['name']}")

ftp.quit()
PY

find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'vps-config-*.tar.gz' -mtime "+$LOCAL_KEEP_DAYS" -delete
echo "backup complete: $ARCHIVE"
