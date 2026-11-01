#!/usr/bin/env python3
"""Preflight VM 100's system-disk backup; --run enables live snapshot-mode backup."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess


MOUNT = Path("/mnt/proxmox-backups")
UUID = "4a364e8f-b6b1-4e70-892b-afa4ab81ed5d"
STORAGE = "proxmox-backups"


def query(*args):
    return subprocess.run(args, check=True, capture_output=True,
                          text=True, timeout=20).stdout


def drive(value):
    # QEMU's property string: first token is the volume, followed by key=value.
    parts = value.split(",")
    result = {"file": parts[0]}
    for item in parts[1:]:
        key, separator, value = item.partition("=")
        if not separator or key in result:
            raise ValueError("unsupported or duplicate disk property")
        result[key] = value
    return result


def check_vm(config):
    if config.get("name") != "omv" or config.get("lock") or config.get("template"):
        raise ValueError("VM 100 must be the unlocked, non-template OMV VM")
    disks = {key: drive(value) for key, value in config.items()
             if re.fullmatch(r"(?:ide|sata|scsi|virtio)\d+", key)}
    data = {key: value for key, value in disks.items() if value.get("media") != "cdrom"}
    if set(data) != {"scsi0", "scsi1", "scsi2", "scsi3"}:
        raise ValueError("unexpected VM disks; inspect current qm config 100")
    system = data["scsi0"]
    if (system["file"] != "local-lvm:vm-100-disk-0" or system.get("size") != "80G"
            or system.get("backup", "1") != "1"):
        raise ValueError("expected the included 80G scsi0 system disk on local-lvm")
    for key in ("scsi1", "scsi2", "scsi3"):
        if not data[key]["file"].startswith("/dev/disk/by-id/") or data[key].get("backup") != "0":
            raise ValueError(f"{key}: physical HDD must use by-id and explicit backup=0")
    return data


def check_storage(config):
    if (config.get("type") != "dir" or config.get("path") != str(MOUNT)
            or config.get("disable") or "backup" not in config.get("content", "").split(",")):
        raise ValueError("unexpected or disabled backup storage configuration")


def preflight():
    if os.geteuid() != 0 or not Path("/etc/pve").is_dir():
        raise ValueError("run as root on Proxmox, not inside OMV")
    check_storage(json.loads(query("pvesh", "get", f"/storage/{STORAGE}", "--output-format", "json")))
    if not os.path.ismount(MOUNT):
        raise ValueError("backup disk is not mounted")
    actual = query("findmnt", "-rn", "-o", "UUID", "--mountpoint", str(MOUNT)).strip()
    if actual != UUID:
        raise ValueError("backup disk UUID does not match the expected independent disk")
    free = shutil.disk_usage(MOUNT).free
    if free < 90 * 1024 ** 3:
        raise ValueError("less than 90 GiB free on the backup disk")
    config = json.loads(query("pvesh", "get", "/nodes/localhost/qemu/100/config", "--output-format", "json"))
    check_vm(config)
    if query("qm", "status", "100").strip() != "status: running":
        raise ValueError("expected VM 100 to be running before the first backup")
    query("qm", "agent", "100", "ping")
    print("OK: VM 100; scsi0 80G included; three physical HDDs explicitly excluded", flush=True)
    print(f"OK: independent backup disk mounted; free space {free // (1024 ** 3)} GiB", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true", help="run vzdump in live snapshot mode without shutting down OMV")
    args = parser.parse_args()
    try:
        preflight()
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        print("STOP: preflight failed; inspect qm config 100, pvesm status and the backup mount")
        return 2
    if not args.run:
        print("Preflight only. Use --run for a live snapshot backup; OMV will stay running.")
        return 0
    print("Backing up OMV in live snapshot mode; no VM shutdown. Guest agent may briefly freeze filesystem writes.", flush=True)
    result = subprocess.run([
        "vzdump", "100", "--storage", STORAGE, "--mode", "snapshot",
        "--compress", "zstd", "--remove", "0",
    ])
    subprocess.run(["qm", "status", "100"], check=False)
    if result.returncode:
        print("ERROR: backup failed; inspect the log and VM status; do not delete recovery material")
        return result.returncode
    print("OK: vzdump finished. Archive integrity and recovery verification are still required.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
