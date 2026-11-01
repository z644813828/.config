#!/usr/bin/env python3
"""Local Proxmox recovery bundle. Default: preflight only; --run creates it."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import time


MOUNT = Path("/mnt/proxmox-backups")
UUID = "4a364e8f-b6b1-4e70-892b-afa4ab81ed5d"
DATABASE = Path("/var/lib/pve-cluster/config.db")
CONTAINERS = ("vpn-gateway", "monit-telegram")
QUEUE_VOLUME = "proxmox-monit-telegram-queue"
QUEUE_PATH = "/var/lib/monit-telegram/queue.sqlite3"
STATE = Path("/root/.backup-secrets/proxmox-vpn-gateway")
REQUIRED = (
    Path("/etc"), Path("/usr/local"), Path("/opt/proxmox-vpn-gateway"),
    Path("/root/.ssh"), Path("/root/.backup-secrets"), Path("/var/spool/cron"),
)
OPTIONAL = tuple(Path("/root") / name for name in (
    ".config", ".local", ".vim", ".bashrc", ".profile", ".bash_profile",
    ".tmux.conf", ".gitconfig", ".vimrc",
))


def query(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError(f"{Path(args[0]).name} query failed; output withheld")
    return result.stdout


def disk_guard():
    if not MOUNT.is_mount():
        raise ValueError("backup HDD is not mounted")
    if query("findmnt", "-rn", "-o", "UUID", "--mountpoint", str(MOUNT)).strip() != UUID:
        raise ValueError("backup HDD UUID mismatch")
    if shutil.disk_usage(MOUNT).free < 10 * 1024 ** 3:
        raise ValueError("less than 10 GiB free on backup HDD")


def validate_containers(items):
    if len(items) != len(CONTAINERS) or {c.get("Name") for c in items} != {"/" + name for name in CONTAINERS}:
        raise ValueError("unexpected container inventory")
    for container in items:
        state = container.get("State", {})
        if not state.get("Running") or state.get("Paused"):
            raise ValueError("both host containers must be running and not paused")
        if not container.get("Image", "").startswith("sha256:"):
            raise ValueError("missing immutable Docker image ID")
        mounts = {m["Destination"]: m for m in container.get("Mounts", [])}
        if container["Name"] == "/vpn-gateway":
            expected = {
                "/etc/wireguard": STATE / "etc/wireguard",
                "/root/.ssh": STATE / "root/.ssh",
                "/usr/local/bin/start-host-forwards": Path("/opt/proxmox-vpn-gateway/start-host-forwards"),
            }
            if set(mounts) != set(expected):
                raise ValueError("unreviewed VPN mount inventory")
            for target, source in expected.items():
                mount = mounts[target]
                if mount.get("Type") != "bind" or Path(mount["Source"]).resolve() != source.resolve():
                    raise ValueError("VPN persistent state path differs from expected")
        else:
            mount = mounts.get("/var/lib/monit-telegram", {})
            if (set(mounts) != {"/var/lib/monit-telegram"} or mount.get("Type") != "volume"
                    or mount.get("Name") != QUEUE_VOLUME):
                raise ValueError("unreviewed Telegram queue mount")
            env = dict(value.split("=", 1) for value in container.get("Config", {}).get("Env", [])
                       if "=" in value)
            if env.get("QUEUE_DB", QUEUE_PATH) != QUEUE_PATH:
                raise ValueError("unreviewed Telegram database path")


def preflight():
    if os.geteuid() != 0 or not Path("/etc/pve").is_mount():
        raise ValueError("run locally as root on Proxmox with pmxcfs mounted")
    if Path("/etc/pve/corosync.conf").exists():
        raise ValueError("cluster deployment requires a separately reviewed recovery plan")
    for executable in ("docker", "tar", "gzip", "findmnt", "pveversion", "pvesm", "qm", "ip", "lsblk"):
        if not shutil.which(executable):
            raise ValueError("required program missing: " + executable)
    disk_guard()
    for path in (*REQUIRED, DATABASE, Path("/etc/monit-telegram.env"),
                 Path("/etc/apparmor.d/proxmox-monit-telegram"),
                 STATE / "etc/wireguard/wg0.conf", STATE / "root/.ssh/authorized_keys"):
        if not path.exists():
            raise ValueError("required recovery material missing: " + str(path))
    if set(query("docker", "ps", "--format", "{{.Names}}").splitlines()) != set(CONTAINERS):
        raise ValueError("running Docker containers differ from reviewed two-container host")
    containers = json.loads(query("docker", "inspect", *CONTAINERS))
    validate_containers(containers)
    queue_source()
    print("OK: standalone Proxmox; independent backup HDD; host state and two containers found", flush=True)
    print("Scope: host config/keys, pmxcfs database, Docker images/rootfs, Telegram queue", flush=True)
    print("Excluded: VM disks, data HDDs, old SSD, migration bundles; no service shutdown", flush=True)
    return containers


def sqlite_copy(source, destination):
    deadline = time.monotonic() + 60

    def progress(*_):
        if time.monotonic() > deadline:
            raise ValueError("SQLite snapshot timed out")

    with closing(sqlite3.connect(source.resolve().as_uri() + "?mode=ro", uri=True, timeout=10)) as original:
        with closing(sqlite3.connect(destination)) as saved:
            original.backup(saved, pages=256, progress=progress)
            if saved.execute("PRAGMA quick_check").fetchall() != [("ok",)]:
                raise ValueError("SQLite snapshot integrity failed")
    destination.chmod(0o600)


def private_directory(path):
    if path.is_symlink():
        raise ValueError("backup directory must not be a symlink")
    path.mkdir(mode=0o700, exist_ok=True)
    info = path.stat()
    if info.st_uid != 0 or info.st_mode & 0o077:
        raise ValueError("backup directory must be root-owned with mode 0700")


def json_file(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")
    path.chmod(0o600)


def execute(stage, *args):
    # All potentially private diagnostics remain in the protected bundle.
    with (stage / "commands.log").open("ab") as log:
        result = subprocess.run(args, stdout=log, stderr=log)
    if result.returncode:
        raise ValueError(f"{Path(args[0]).name} failed; private diagnostics retained in partial bundle")


def queue_source():
    volumes = json.loads(query("docker", "volume", "inspect", QUEUE_VOLUME))
    if (len(volumes) != 1 or volumes[0].get("Name") != QUEUE_VOLUME
            or volumes[0].get("Driver") != "local" or volumes[0].get("Options")):
        raise ValueError("Telegram queue requires a reviewed local Docker volume")
    mountpoint = Path(volumes[0].get("Mountpoint", ""))
    if not mountpoint.is_absolute() or mountpoint.is_symlink() or not mountpoint.is_dir():
        raise ValueError("Telegram queue volume directory is unavailable")
    source = mountpoint / "queue.sqlite3"
    if source.is_symlink() or not source.is_file():
        raise ValueError("Telegram queue database is missing or is a symlink")
    return source


def queue_snapshot(stage):
    # Use HOST SQLite's online backup API on the volume, including committed WAL.
    # The imported container's SQLite library need not implement serialize().
    sqlite_copy(queue_source(), stage / "telegram-queue.sqlite3")


def checksum_files(stage):
    rows = []
    for path in sorted(stage.iterdir()):
        if path.is_file() and path.name not in ("SHA256SUMS", "COMPLETE"):
            digest = hashlib.sha256()
            with path.open("rb") as source:
                for block in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(block)
            rows.append(f"{digest.hexdigest()}  {path.name}\n")
    (stage / "SHA256SUMS").write_text("".join(rows))
    for path in stage.iterdir():
        if path.is_file():
            path.chmod(0o600)


RESTORE = """PROXMOX HOST RECOVERY BUNDLE - CONTAINS UNENCRYPTED SECRETS
This is not a bootable SSD image and contains no VM disks. Keep mode 0700/0600.
Verify SHA256SUMS before using any artifact; COMPLETE means creation checks passed,
not that recovery was tested. Protect a second, encrypted off-host copy.

host-files.tar.gz: /etc EXCEPT /etc/pve, /usr/local, gateway /opt, root SSH,
backup secrets and selected shell/config dirs, cron. ACLs/xattrs preserved.
pmxcfs-config.db: consistent SQLite snapshot of /var/lib/pve-cluster/config.db;
this holds /etc/pve, including VM configs, storage, users and private keys.
docker-images.tar.gz: exact immutable images; inspect JSON records original tags.
*-rootfs.tar.gz: live Docker exports, preserving writable-layer files but NOT
mount contents or image metadata. These are not globally atomic filesystem
snapshots. Inspect them for needed changes; do not boot stale runtime PID files.
telegram-queue.sqlite3: consistent snapshot of the mounted queue DB (includes WAL
transactions). Restoring it may replay notifications; decide whether to retain it.
inventory.json/docker-inspect.json/docker-diff-*.txt are PRIVATE recovery context.

Recovery order, on an isolated replacement with nothing running:
1. Install compatible Proxmox/Debian, verify disks by UUID/by-id, preserve data HDDs.
2. Review host network, hostname, hosts, users, packages and keys selectively.
   NEVER blindly untar /etc over a running host or rejoin a live cluster by copying keys.
3. For standalone pmxcfs recovery, follow official documentation: stop pve-cluster
   ON THE REPLACEMENT, restore config.db mode 0600, reconcile hostname/hosts and
   reboot. Do not run this on the working source. VM configuration is not VM data.
4. Reinstall Docker/Monit/APC/socat, restore protected mounts and AppArmor/unit
   files, load saved images and retag IDs using docker-inspect.json. Recreate
   containers from recorded runtime flags, not docker import alone. Review live
   export changes before replacing images; Docker exports omit volumes.
5. Restore queue only while notifier is stopped, into its original named volume.
   Restore gateway state/stub and host relay unit, then test from an independent
   console. NEVER run two gateways with the same WireGuard keys or duplicate host IPs.
6. Restore VM 100 from its separate vzdump backup. Verify physical disk mappings
   before attaching production HDDs; an isolated test must not attach them.
7. Test network, VPN, UPS, notifications, guest startup/shutdown, storage and apps.

No services were stopped for this backup. Do not change host/container config
during collection. No schedule, pruning, encryption or Google Drive upload is set.
Official pmxcfs recovery: https://github.com/proxmox/pve-docs/blob/master/pmxcfs.adoc
"""


def create_bundle(containers):
    private_directory(MOUNT / "host-config")
    name = "proxmox-host-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    stage = MOUNT / "host-config" / ("." + name + ".partial")
    stage.mkdir(mode=0o700)
    print("Working directory (private):", stage, flush=True)
    shutil.copyfile(Path(__file__), stage / "backup_host.py")
    print("1/5: pmxcfs and Telegram SQLite snapshots", flush=True)
    disk_guard()
    sqlite_copy(DATABASE, stage / "pmxcfs-config.db")
    queue_snapshot(stage)
    print("2/5: host files and private recovery inventory", flush=True)
    paths = [*REQUIRED, *(p for p in OPTIONAL if p.exists())]
    execute(stage, "tar", "--acls", "--xattrs", "--numeric-owner", "--one-file-system",
            "--exclude=etc/pve", "-czf", str(stage / "host-files.tar.gz"), "-C", "/",
            *[str(p).lstrip("/") for p in paths])
    json_file(stage / "docker-inspect.json", containers)
    inventory = {}
    for label, command in {
        "versions": ("pveversion", "-v"), "storage": ("pvesm", "status"),
        "vms": ("qm", "list"), "vm100": ("qm", "config", "100"),
        "disks": ("lsblk", "--json", "-o", "NAME,PATH,SIZE,FSTYPE,UUID,MODEL,SERIAL,MOUNTPOINTS"),
        "addresses": ("ip", "-j", "addr"), "routes": ("ip", "-j", "route", "show", "table", "all"),
        "packages": ("dpkg-query", "-W"),
    }.items():
        inventory[label] = query(*command)
    for command in (("nft", "list", "ruleset"), ("iptables-save",), ("apt-mark", "showmanual")):
        if shutil.which(command[0]):
            inventory[command[0]] = query(*command)
    json_file(stage / "inventory.json", inventory)
    for container in CONTAINERS:
        (stage / f"docker-diff-{container}.txt").write_text(query("docker", "diff", container))
    print("3/5: exact host Docker images (may take several minutes)", flush=True)
    disk_guard()
    images = sorted({item["Image"] for item in containers})
    execute(stage, "docker", "image", "save", "--output", str(stage / "docker-images.tar"), *images)
    execute(stage, "gzip", "-1", "-n", str(stage / "docker-images.tar"))
    print("4/5: live container root filesystems (persistent binds saved separately)", flush=True)
    for container in CONTAINERS:
        disk_guard()
        destination = stage / (container + "-rootfs.tar")
        execute(stage, "docker", "export", "--output", str(destination), container)
        execute(stage, "gzip", "-1", "-n", str(destination))
    print("5/5: archive integrity and SHA-256 checksums", flush=True)
    for path in stage.glob("*.tar.gz"):
        execute(stage, "gzip", "-t", str(path))
        execute(stage, "tar", "-tzf", str(path))
    (stage / "RESTORE.txt").write_text(RESTORE)
    checksum_files(stage)
    disk_guard()
    (stage / "COMPLETE").write_text(datetime.now(timezone.utc).isoformat() + "\n")
    (stage / "COMPLETE").chmod(0o600)
    final = stage.with_name(name)
    if final.exists():
        raise ValueError("final bundle already exists; nothing overwritten")
    stage.rename(final)
    print("OK: host bundle created and archive/SQLite checks passed:", final, flush=True)
    print("Contains UNENCRYPTED SECRETS. No off-host copy or recovery test yet.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    args = parser.parse_args()
    os.umask(0o077)
    if not args.run:
        preflight()
        print("Preflight only. Use --run to create the private host bundle.")
        return
    with open("/run/proxmox-host-backup.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        create_bundle(preflight())


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, sqlite3.Error, subprocess.SubprocessError) as error:
        if isinstance(error, ValueError):
            print("Reason:", error)
        raise SystemExit("STOP: host backup incomplete. Keep the private .partial directory for diagnosis; no backup or running service was removed.") from None
