#!/usr/bin/env python3
import argparse
import ftplib
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_FILE = Path("/root/.backup-secrets/pull-vps-backups-from-ftp.env")


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
    tmp.replace(local)
    print("  got  {}".format(name))


def mirror_dir(ftp, remote_dir, local_dir):
    local_dir.mkdir(parents=True, exist_ok=True)

    try:
        ftp.cwd(remote_dir)
    except ftplib.error_perm as exc:
        print("skip: cannot cwd to {}: {}".format(remote_dir, exc))
        return

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
