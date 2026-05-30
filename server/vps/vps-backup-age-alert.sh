#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-/root/.vps-config-backup.env}"
MAX_AGE_HOURS="${BACKUP_ALERT_MAX_AGE_HOURS:-36}"
STATE_DIR="${STATE_DIR:-/var/lib/vps-config-backup}"
STATE_FILE="$STATE_DIR/backup-age-alert.state"

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
export FTP_HOST FTP_USER FTP_PASS REMOTE_DIR HOST_ID MAX_AGE_HOURS STATE_FILE

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

python3 <<'PY'
import ftplib
import os
import sqlite3
import sys
import time
import urllib.parse
import urllib.request

ftp_host = os.environ["FTP_HOST"]
ftp_user = os.environ["FTP_USER"]
ftp_pass = os.environ["FTP_PASS"]
remote_dir = os.environ["REMOTE_DIR"]
host_id = os.environ["HOST_ID"]
max_age_hours = float(os.environ.get("MAX_AGE_HOURS", "36"))
state_file = os.environ["STATE_FILE"]
pattern_prefix = f"vps-config-{host_id}-"
now = time.time()


def load_tg_settings():
    conn = sqlite3.connect("/etc/x-ui/x-ui.db")
    rows = dict(conn.execute(
        'select key, value from settings where key in ("tgBotToken","tgBotChatId","tgBotAPIServer")'
    ))
    conn.close()
    token = (rows.get("tgBotToken") or "").strip()
    chat_id = (rows.get("tgBotChatId") or "").strip()
    api = (rows.get("tgBotAPIServer") or "https://api.telegram.org").strip().rstrip("/")
    if not token or not chat_id:
        raise RuntimeError("Telegram token/chat id are missing in 3x-ui settings")
    return api, token, chat_id


def send_telegram(text):
    api, token, chat_id = load_tg_settings()
    data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
    req = urllib.request.Request(f"{api}/bot{token}/sendMessage", data=data)
    with urllib.request.urlopen(req, timeout=20) as resp:
        body = resp.read().decode("utf-8", "replace")
    if '"ok":true' not in body:
        raise RuntimeError("Telegram API did not confirm message")


def read_state():
    try:
        with open(state_file, "r", encoding="utf-8") as fh:
            return fh.read().strip()
    except FileNotFoundError:
        return ""


def write_state(value):
    tmp = state_file + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(value + "\n")
    os.replace(tmp, state_file)


def ftp_latest_backup():
    ftp = ftplib.FTP()
    ftp.connect(ftp_host, 21, timeout=30)
    ftp.login(ftp_user, ftp_pass)
    ftp.cwd(remote_dir)
    latest = None
    for name in ftp.nlst():
        if not (name.startswith(pattern_prefix) and name.endswith(".tar.gz")):
            continue
        mtime = 0
        try:
            resp = ftp.sendcmd(f"MDTM {name}")
            if resp.startswith("213 "):
                mtime = time.mktime(time.strptime(resp[4:].strip(), "%Y%m%d%H%M%S"))
        except Exception:
            pass
        item = (mtime, name)
        if latest is None or item > latest:
            latest = item
    ftp.quit()
    return latest


latest = ftp_latest_backup()
if latest is None:
    alert_key = "missing"
    if read_state() != alert_key:
        send_telegram(f"Backup alert on {host_id}: no backups found in {remote_dir}.")
        write_state(alert_key)
    print("backup alert: no backups found")
    sys.exit(1)

mtime, name = latest
age_hours = (now - mtime) / 3600 if mtime else 999999
alert_key = f"{name}:{int(mtime)}"
if age_hours > max_age_hours:
    if read_state() != alert_key:
        send_telegram(
            f"Backup alert on {host_id}: latest FTP backup is older than {max_age_hours:.0f}h. "
            f"Latest: {name}, age: {age_hours:.1f}h."
        )
        write_state(alert_key)
    print(f"backup alert: latest={name} age={age_hours:.1f}h")
    sys.exit(1)

if read_state():
    write_state("")
print(f"backup ok: latest={name} age={age_hours:.1f}h")
PY
