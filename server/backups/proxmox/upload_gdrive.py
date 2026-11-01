#!/usr/bin/env python3
"""Plan or upload two latest completed generations per VM/host via rclone crypt."""
import argparse
import configparser
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path("/mnt/proxmox-backups")
UUID = "4a364e8f-b6b1-4e70-892b-afa4ab81ed5d"
CONFIG = Path("/root/.config/rclone/rclone.conf")
REMOTE = "gdrive_crypt:proxmox-backups"
VM = re.compile(r"vzdump-qemu-(\d+)-(\d{4}_\d{2}_\d{2}-\d{2}_\d{2}_\d{2})\.vma\.zst")
HOST = re.compile(r"proxmox-host-\d{8}T\d{6}Z")


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def guard():
    if os.geteuid() != 0 or not Path("/etc/pve").is_mount() or not ROOT.is_mount():
        raise ValueError("run as root on Proxmox with both filesystems mounted")
    uuid = subprocess.run(["findmnt", "-rn", "-o", "UUID", "--mountpoint", str(ROOT)],
                          check=True, capture_output=True, text=True).stdout.strip()
    if uuid != UUID:
        raise ValueError("backup disk UUID mismatch")
    for name in ("dump", "host-config"):
        directory = ROOT / name
        if directory.is_symlink() or not directory.is_dir():
            raise ValueError("backup source directory is missing or is a symlink")
    for executable in ("rclone", "zstd", "vma", "bash"):
        if not shutil.which(executable):
            raise ValueError("missing executable: " + executable)
    info = CONFIG.stat()
    if CONFIG.is_symlink() or info.st_uid != 0 or info.st_mode & 0o077:
        raise ValueError("rclone config must be a root-owned private regular file")
    config = configparser.ConfigParser(interpolation=None)
    config.read(CONFIG)
    if config.get("gdrive_crypt", "type", fallback="") != "crypt":
        raise ValueError("gdrive_crypt is not configured as crypt")


def selections(keep=2):
    groups = {}
    for path in (ROOT / "dump").glob("*.vma.zst"):
        match = VM.fullmatch(path.name)
        if not match or path.is_symlink() or not path.is_file():
            continue
        vmid, stamp = match.groups()
        log = path.with_name(path.name.removesuffix(".vma.zst") + ".log")
        if not log.is_file() or log.is_symlink():
            continue
        text = log.read_text()
        if not re.search(r"Finished Backup of VM " + re.escape(vmid) + r"\b", text):
            continue
        if re.search(r"^\s*(?:INFO:\s*)?ERROR\b", text, re.M):
            continue
        groups.setdefault(vmid, []).append((stamp, path, log))
    result = []
    for vmid in sorted(groups):
        for stamp, archive, log in sorted(groups[vmid], reverse=True)[:keep]:
            result.append((f"vm/{vmid}/{stamp}", [archive, log]))
    hosts = [p for p in (ROOT / "host-config").iterdir()
             if HOST.fullmatch(p.name) and not p.is_symlink() and p.is_dir()
             and (p / "COMPLETE").is_file() and (p / "COMPLETE").stat().st_size > 0]
    for folder in sorted(hosts, reverse=True)[:keep]:
        paths = sorted(folder.iterdir())
        if any(p.is_symlink() or not p.is_file() for p in paths):
            raise ValueError("host bundle contains unexpected entries")
        if not (folder / "SHA256SUMS").is_file():
            raise ValueError("completed host bundle lacks SHA256SUMS")
        result.append(("host/" + folder.name, paths))
    if not any(name.startswith("vm/") for name, _ in result) or not hosts:
        raise ValueError("need at least one finished VM archive and one completed host bundle")
    return result


def verify_host(folder):
    expected = {}
    for line in (folder / "SHA256SUMS").read_text().splitlines():
        match = re.fullmatch(r"([a-f0-9]{64})  ([A-Za-z0-9][A-Za-z0-9_.-]*)", line)
        if not match or match[2] in expected or match[2] in ("SHA256SUMS", "COMPLETE"):
            raise ValueError("invalid host SHA256SUMS manifest")
        expected[match[2]] = match[1]
    actual = {p.name for p in folder.iterdir()}
    if not expected or actual != set(expected) | {"SHA256SUMS", "COMPLETE"}:
        raise ValueError("host bundle files differ from manifest")
    for name, value in expected.items():
        path = folder / name
        if path.is_symlink() or not path.is_file() or digest(path) != value:
            raise ValueError("host bundle SHA-256 verification failed")


def execute(log, *args):
    with log.open("ab") as output:
        result = subprocess.run(args, stdout=output, stderr=output)
    if result.returncode:
        raise ValueError(f"{Path(args[0]).name} failed (exit {result.returncode}); diagnostics in private log")


def rclone(log, *args):
    execute(log, "rclone", "--config", str(CONFIG), *args, "--bwlimit", "10M",
            "--checkers", "4", "--transfers", "2", "--retries", "3",
            "--low-level-retries", "10", "--stats", "1m", "--log-level", "INFO")


def signature(path):
    info = path.stat()
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns


def remote_marker(destination, log):
    with log.open("ab") as errors:
        result = subprocess.run([
            "rclone", "--config", str(CONFIG), "cat", destination + "/UPLOAD-COMPLETE.json",
        ], stdout=subprocess.PIPE, stderr=errors, text=True, timeout=120)
    if result.returncode in (3, 4):
        return None
    if result.returncode:
        raise ValueError("cannot determine remote generation state")
    marker = json.loads(result.stdout)
    if not isinstance(marker, dict) or marker.get("schema") != 1:
        raise ValueError("invalid remote completion marker")
    return marker


def upload(name, paths, log):
    guard()
    # Hardlinks keep source files available if a separate retention job unlinks them;
    # no archive-size copy and no modification/chmod of source inodes is performed.
    with tempfile.TemporaryDirectory(prefix=".gdrive-stage-", dir=ROOT) as temporary:
        stage = Path(temporary)
        stage.chmod(0o700)
        for path in paths:
            if path.is_symlink() or not path.is_file():
                raise ValueError("source is missing or is a symlink")
            os.link(path, stage / path.name, follow_symlinks=False)
        before = {p.name: signature(p) for p in stage.iterdir()}
        if name.startswith("host/"):
            verify_host(stage)
        else:
            archive = next(p for p in stage.iterdir() if p.name.endswith(".vma.zst"))
            print("Checking local VMA:", archive.name, flush=True)
            execute(log, "zstd", "-t", str(archive))
            execute(log, "bash", "-o", "pipefail", "-c",
                    'zstd -dc -- "$1" | vma verify -', "_", str(archive))
            (stage / "SHA256SUMS").write_text("".join(
                f"{digest(stage / filename)}  {filename}\n" for filename in sorted(before)))
        destination = REMOTE + "/" + name
        marker_before = remote_marker(destination, log)
        if marker_before is not None:
            if (marker_before.get("generation") != name
                    or marker_before.get("manifest_sha256") != digest(stage / "SHA256SUMS")):
                raise ValueError("committed remote generation differs; refusing to overwrite")
            print("Already uploaded; rechecking without overwriting:", destination, flush=True)
        else:
            print("Uploading:", destination, flush=True)
            rclone(log, "copy", str(stage), destination)
        print("Verifying encrypted remote:", destination, flush=True)
        rclone(log, "cryptcheck", str(stage), destination, "--one-way")
        if any(signature(stage / filename) != value for filename, value in before.items()):
            raise ValueError("source changed during upload; no new completion marker written")
        if marker_before is not None:
            print("OK: existing verified generation:", name, flush=True)
            return digest(stage / "SHA256SUMS")
        marker = stage / "UPLOAD-COMPLETE.json"
        marker.write_text(json.dumps({
            "schema": 1, "generation": name,
            "verified_at": datetime.now(timezone.utc).isoformat(),
            "manifest_sha256": digest(stage / "SHA256SUMS"),
            "verification": "rclone cryptcheck",
        }, indent=2) + "\n")
        # A local host COMPLETE file alone is NOT evidence of remote verification.
        rclone(log, "copyto", str(marker), destination + "/" + marker.name)
        print("OK:", name, flush=True)
        return digest(stage / "SHA256SUMS")


def capture(log, *args, missing=False):
    with log.open("ab") as errors:
        result = subprocess.run(args, stdout=subprocess.PIPE, stderr=errors, text=True, timeout=120)
    if missing and result.returncode in (3, 4):
        return ""
    if result.returncode:
        raise ValueError("rotation inventory query failed; see private log")
    return result.stdout


def valid_generation(name):
    parts = name.split("/")
    return ((len(parts) == 2 and parts[0] == "host" and HOST.fullmatch(parts[1]))
            or (len(parts) == 3 and parts[0] == "vm" and re.fullmatch(r"\d+", parts[1])
                and re.fullmatch(r"\d{4}_\d{2}_\d{2}-\d{2}_\d{2}_\d{2}", parts[2])))


def checked_marker(name, log):
    if not valid_generation(name):
        raise ValueError("unsafe rotation generation")
    marker = remote_marker(REMOTE + "/" + name, log)
    if marker is not None and (marker.get("generation") != name
            or marker.get("verification") != "rclone cryptcheck"
            or not re.fullmatch(r"[a-f0-9]{64}", marker.get("manifest_sha256", ""))):
        raise ValueError("rotation requires a valid verified-generation marker")
    return marker


def rotation_plan(selected, log, receipts=None):
    # Native inventory respects Proxmox protection and confirms the storage mapping.
    storage = json.loads(capture(log, "pvesh", "get", "/storage/proxmox-backups", "--output-format", "json"))
    if storage.get("type") != "dir" or storage.get("path") != str(ROOT) or storage.get("disable"):
        raise ValueError("unexpected Proxmox storage mapping; refusing rotation")
    inventory = json.loads(capture(log, "pvesh", "get", "/nodes/localhost/storage/proxmox-backups/content",
                                   "--content", "backup", "--output-format", "json"))
    protected = {item["volid"].split("/")[-1] for item in inventory if item.get("protected")}
    keepers = {}
    for name, _ in selected:
        keepers.setdefault(name.rsplit("/", 1)[0], set()).add(name)
    all_local = dict(selections(keep=None))
    plan = {"keep": {}, "remote": [], "local": []}
    for group, keep in keepers.items():
        if len(keep) < 2:
            print("ROTATION SKIP: fewer than two completed local generations:", group)
            continue
        committed = {}
        listing = capture(log, "rclone", "--config", str(CONFIG), "lsf", REMOTE + "/" + group,
                          "--dirs-only", missing=True)
        for directory in listing.splitlines():
            name = group + "/" + directory.rstrip("/")
            if not valid_generation(name):
                continue
            marker = checked_marker(name, log)
            if marker is not None:
                committed[name] = marker
        if not keep <= set(committed):
            print("ROTATION SKIP: two replacement cloud generations are not committed:", group)
            continue
        if set(sorted(committed, reverse=True)[:2]) != keep:
            print("ROTATION SKIP: cloud has newer generations absent from local selection:", group)
            continue
        for name in keep:
            if receipts is not None and receipts.get(name) != committed[name]["manifest_sha256"]:
                raise ValueError("replacement generation was not verified in this run")
            plan["keep"][name] = committed[name]["manifest_sha256"]
        for name in sorted(set(committed) - keep):
            if committed[name].get("protected"):
                continue
            if name.startswith("vm/"):
                _, vmid, stamp = name.split("/")
                if f"vzdump-qemu-{vmid}-{stamp}.vma.zst" in protected:
                    continue
            plan["remote"].append(name)
        for name, paths in all_local.items():
            if name.rsplit("/", 1)[0] != group or name in keep:
                continue
            # A new backup may finish while uploading. Never prune a generation
            # newer than the two replacements verified by THIS run.
            if name >= min(keep):
                continue
            if name.startswith("vm/") and paths[0].name in protected:
                continue
            if name.startswith("host/"):
                verify_host(paths[0].parent)
            plan["local"].append({"name": name, "paths": [str(p) for p in paths],
                                  "signatures": [list(signature(p)) for p in paths]})
    return plan


def apply_rotation(plan, log, receipts):
    guard()
    groups = {}
    for name in plan["keep"]:
        groups.setdefault(name.rsplit("/", 1)[0], set()).add(name)
    if any(len(names) != 2 for names in groups.values()):
        raise ValueError("rotation requires two verified replacements in each group")
    for name, expected in plan["keep"].items():
        marker = checked_marker(name, log)
        if marker is None or marker["manifest_sha256"] != expected or receipts.get(name) != expected:
            raise ValueError("replacement generation verification changed; rotation aborted")
    # Validate every path BEFORE the first deletion, not halfway through cleanup.
    for item in plan["local"]:
        group = item["name"].rsplit("/", 1)[0]
        if (not valid_generation(item["name"]) or group not in groups
                or item["name"] >= min(groups[group])):
            raise ValueError("unsafe local rotation entry")
        for value, saved in zip(item["paths"], item["signatures"], strict=True):
            path = Path(value)
            if path.is_symlink() or not path.is_file() or list(signature(path)) != saved:
                raise ValueError("local rotation candidate changed")
            if item["name"].startswith("host/"):
                if path.parent != ROOT / "host-config" / item["name"].split("/")[1]:
                    raise ValueError("host rotation path escaped expected directory")
            elif path.parent != ROOT / "dump":
                raise ValueError("VM rotation path escaped dump directory")
        if item["name"].startswith("vm/"):
            _, vmid, stamp = item["name"].split("/")
            base = f"vzdump-qemu-{vmid}-{stamp}"
            if item["paths"] != [str(ROOT / "dump" / (base + ".vma.zst")),
                                  str(ROOT / "dump" / (base + ".log"))]:
                raise ValueError("VM filenames do not match rotation generation")
    # Persist a private journal first. Failure can leave partial cleanup, not lost replacements.
    journal = log.with_suffix(".rotation.json")
    with journal.open("x") as output:
        json.dump(plan, output, indent=2)
    for name in plan["remote"]:
        group = name.rsplit("/", 1)[0]
        if (not valid_generation(name) or name in plan["keep"]
                or group not in groups or name >= min(groups[group])):
            raise ValueError("unsafe cloud rotation entry")
        guard()
        # No purge: only manifest-listed files are removed; unrelated additions survive.
        destination = REMOTE + "/" + name
        old_marker = checked_marker(name, log)
        if old_marker is None:
            raise ValueError("old generation marker disappeared")
        manifest = capture(log, "rclone", "--config", str(CONFIG), "cat", destination + "/SHA256SUMS")
        if hashlib.sha256(manifest.encode()).hexdigest() != old_marker["manifest_sha256"]:
            raise ValueError("old remote manifest does not match verified marker")
        files = []
        for line in manifest.splitlines():
            match = re.fullmatch(r"[a-f0-9]{64}  ([A-Za-z0-9][A-Za-z0-9_.-]*)", line)
            if not match or match[1] in ("SHA256SUMS", "COMPLETE", "UPLOAD-COMPLETE.json"):
                raise ValueError("unsafe old remote manifest")
            files.append(match[1])
        if not files or len(set(files)) != len(files):
            raise ValueError("empty old remote manifest")
        metadata = ["SHA256SUMS", "UPLOAD-COMPLETE.json"] + (["COMPLETE"] if name.startswith("host/") else [])
        actual = capture(log, "rclone", "--config", str(CONFIG), "lsf", destination,
                         "--recursive", "--files-only").splitlines()
        if set(actual) != set(files + metadata):
            raise ValueError("old cloud generation contains unexpected/missing files; refusing cleanup")
        # Invalidate old completion before deleting data; interrupted cleanup cannot
        # advertise a partially removed generation as a valid recovery copy.
        rclone(log, "deletefile", destination + "/UPLOAD-COMPLETE.json")
        for filename in files + ["SHA256SUMS"] + (["COMPLETE"] if name.startswith("host/") else []):
            rclone(log, "deletefile", destination + "/" + filename)
        # rmdir fails rather than deleting unrecognized extra files/subdirectories.
        rclone(log, "rmdir", destination)
        print("ROTATED CLOUD:", name, flush=True)
    for item in plan["local"]:
        guard()
        paths = [Path(value) for value in item["paths"]]
        if any(p.is_symlink() or not p.is_file() or list(signature(p)) != saved
               for p, saved in zip(paths, item["signatures"], strict=True)):
            raise ValueError("local rotation candidate changed before deletion")
        if item["name"].startswith("vm/"):
            execute(log, "pvesm", "free", "proxmox-backups:backup/" + paths[0].name)
            # Native free protects the archive; remove only its recorded remaining log.
            for path in paths[1:]:
                if path.exists():
                    path.unlink()
        else:
            for path in paths:
                path.unlink()
            paths[0].parent.rmdir()
        print("ROTATED LOCAL:", item["name"], flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--prune", action="store_true", help="rotate local/cloud copies to two verified generations after upload")
    args = parser.parse_args()
    os.umask(0o077)
    guard()
    selected = selections()
    for name, paths in selected:
        print("PLAN:", name, "files:", len(paths), "bytes:", sum(p.stat().st_size for p in paths))
    print("Two latest local generations selected. Rotation:", "requested" if args.prune else "disabled")
    if not args.run and not args.prune:
        print("PLAN ONLY: use --run to validate, upload and cryptcheck.")
        return
    with open("/run/proxmox-gdrive.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        log_dir = Path("/var/log/proxmox-gdrive")
        if log_dir.is_symlink():
            raise ValueError("log directory must not be a symlink")
        log_dir.mkdir(mode=0o700, exist_ok=True)
        if log_dir.stat().st_uid != 0 or log_dir.stat().st_mode & 0o077:
            raise ValueError("log directory must be root-owned/private")
        log = log_dir / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + ".log")
        # Do not append to a pre-existing or symlinked log.
        with log.open("xb"):
            pass
        print("Private progress/error log:", log, flush=True)
        selected = selections()
        receipts = {}
        if args.run:
            for name, paths in selected:
                receipts[name] = upload(name, paths, log)
        if args.prune:
            plan = rotation_plan(selected, log, receipts if args.run else None)
            for name in plan["remote"]:
                print("ROTATION PLAN CLOUD:", name)
            for item in plan["local"]:
                print("ROTATION PLAN LOCAL:", item["name"])
            if args.run:
                apply_rotation(plan, log, receipts)
            else:
                print("PLAN ONLY: no uploads or deletions; use --run --prune after review")
                return
    print("OK: selected generations uploaded and cryptchecked; rotation", "completed" if args.prune else "disabled")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, configparser.Error, subprocess.SubprocessError) as error:
        if isinstance(error, ValueError):
            print("Reason:", error)
        raise SystemExit("STOP: upload/rotation incomplete. No automatic rollback; check private log and rotation journal. Do not share config/log contents without redaction.") from None
