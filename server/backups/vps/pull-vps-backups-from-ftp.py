#!/usr/bin/env python3
import argparse
import ftplib
import os
import re
from datetime import datetime, timedelta
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_FILE = Path("/root/.backup-secrets/pull-vps-backups-from-ftp.env")
ARCHIVE_NAME = re.compile(r"^vps-config-(.+)-(\d{8}T\d{6}Z)\.tar\.gz$")


def load_env(path):
    values = {}
    if not path.exists():
        raise SystemExit("Config file not found: {}".format(path))

    with path.open("r", encoding="utf-8") as file:
        for raw_line in file:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def get_config(args):
    values = load_env(CONFIG_FILE)

    required = ("FTP_HOST", "FTP_USER", "FTP_PASS", "REMOTE_ROOT")
    missing = [key for key in required if not values.get(key)]
    if missing:
        raise SystemExit("Missing required config: {}".format(", ".join(missing)))

    values["DEST_DIR"] = str(args.dest_dir or values.get("DEST_DIR") or "/srv/backups/vps-config")
    try:
        values["LOCAL_RETENTION_DAYS"] = int(values.get("LOCAL_RETENTION_DAYS", "90"))
    except ValueError:
        raise SystemExit("LOCAL_RETENTION_DAYS must be a positive integer")
    if values["LOCAL_RETENTION_DAYS"] <= 0:
        raise SystemExit("LOCAL_RETENTION_DAYS must be a positive integer")
    return values


def remote_names(ftp):
    return sorted(name for name in ftp.nlst() if name not in (".", ".."))


def remote_size(ftp, name):
    try:
        ftp.voidcmd("TYPE I")
        return int(ftp.size(name) or 0)
    except Exception:
        return -1


def download_if_needed(ftp, name, local):
    size = remote_size(ftp, name)
    if local.exists() and size >= 0 and local.stat().st_size == size:
        print("  ok   {}".format(name))
        return

    tmp = local.with_suffix(local.suffix + ".part")
    with tmp.open("wb") as file:
        ftp.retrbinary("RETR {}".format(name), file.write)
    if size >= 0 and tmp.stat().st_size != size:
        raise IOError("Incomplete download: {}".format(name))
    tmp.replace(local)
    print("  got  {}".format(name))


def mirror_dir(ftp, remote_dir, local_dir):
    local_dir.mkdir(parents=True, exist_ok=True)

    try:
        ftp.cwd(remote_dir)
    except ftplib.error_perm as exc:
        print("skip: cannot cwd to {}: {}".format(remote_dir, exc))
        raise

    print("== ftp:{} -> {}".format(remote_dir, local_dir))

    for name in remote_names(ftp):
        remote_path = "{}/{}".format(remote_dir.rstrip("/"), name)
        local_path = local_dir / name

        try:
            ftp.cwd(remote_path)
        except ftplib.error_perm:
            ftp.cwd(remote_dir)
            download_if_needed(ftp, name, local_path)
            continue

        ftp.cwd(remote_dir)
        mirror_dir(ftp, remote_path, local_path)


def prune_local_backups(dest_root, retention_days, now=None):
    cutoff = (now or datetime.utcnow()) - timedelta(days=retention_days)
    groups = {}
    # os.walk does not traverse symlink directories. Never delete their targets.
    for directory, directories, filenames in os.walk(str(dest_root), followlinks=False):
        directories[:] = [name for name in directories
                          if not (Path(directory) / name).is_symlink()]
        for filename in filenames:
            path = Path(directory) / filename
            match = ARCHIVE_NAME.match(filename)
            if not match or path.is_symlink() or not path.is_file():
                continue
            try:
                created = datetime.strptime(match.group(2), "%Y%m%dT%H%M%SZ")
            except ValueError:
                continue
            groups.setdefault((directory, match.group(1)), []).append((created, path))

    removed = 0
    for archives in groups.values():
        archives.sort(key=lambda item: item[0], reverse=True)
        # Even a long outage must not remove the last recovery copies.
        for created, path in archives[3:]:
            if created < cutoff:
                path.unlink()
                removed += 1
                print("  del  {}".format(path))
    print("Local retention: {} days; removed {} old archives".format(retention_days, removed))


def pull_backups(config):
    dest_root = Path(config["DEST_DIR"])
    dest_root.mkdir(parents=True, exist_ok=True)
    remote_root = config["REMOTE_ROOT"].rstrip("/") or "/"

    ftp = ftplib.FTP()
    ftp.connect(config["FTP_HOST"], 21, timeout=30)
    ftp.login(config["FTP_USER"], config["FTP_PASS"])

    try:
        mirror_dir(ftp, remote_root, dest_root)
    finally:
        ftp.quit()

    print("Backups synced to {}".format(dest_root))
    prune_local_backups(dest_root, config["LOCAL_RETENTION_DAYS"])


def parse_args():
    parser = argparse.ArgumentParser(
        description="Pull VPS config-backup archives from FTP to the central server."
    )
    parser.add_argument(
        "--dest-dir",
        type=Path,
        default=None,
        help="Override DEST_DIR from pull-vps-backups-from-ftp.env.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    config = get_config(args)
    pull_backups(config)


if __name__ == "__main__":
    main()
