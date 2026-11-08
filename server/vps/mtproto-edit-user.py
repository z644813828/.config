#!/usr/bin/env python3
"""Edit an MTG client and its WebProxy labels as one recoverable operation."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}\Z")


def run(*args, check=True):
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if check and result.returncode:
        # Never include command output: mtg output can contain credentials.
        raise RuntimeError("Command failed: " + args[0])
    return result


def atomic_write(path, data, metadata):
    fd, tmp = tempfile.mkstemp(prefix="." + path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), metadata.st_mode & 0o777)
            os.fchown(stream.fileno(), metadata.st_uid, metadata.st_gid)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def prepare(root, old, new, port, hostname=""):
    if not NAME.fullmatch(old) or not NAME.fullmatch(new):
        raise ValueError("Invalid client name")
    if not 8443 <= port <= 9000:
        raise ValueError("Port must be between 8443 and 9000")
    config = root / ("etc/mtg-" + old + ".toml")
    unit = root / ("etc/systemd/system/mtg-" + old + ".service")
    new_config = config.with_name("mtg-" + new + ".toml")
    new_unit = unit.with_name("mtg-" + new + ".service")
    if old != new and (new_config.exists() or new_unit.exists()):
        raise ValueError("Client name already exists")
    text = config.read_text()
    unit_text = unit.read_text()
    bind = re.search(r'^bind-to\s*=\s*"0\.0\.0\.0:(\d+)"', text, re.M)
    if not bind:
        raise ValueError("Unsupported MTG bind configuration")
    for other in config.parent.glob("mtg-*.toml"):
        if other != config and re.search(r'bind-to\s*=\s*"[^"]*:' + str(port) + '"', other.read_text()):
            raise ValueError("Port already belongs to another client")
    if int(bind[1]) != port:
        listeners = run("ss", "-H", "-ltn", "sport", "=", ":" + str(port)).stdout
        if listeners.strip():
            raise ValueError("Port is already listening")
    text = text[:bind.start()] + 'bind-to = "0.0.0.0:' + str(port) + '"' + text[bind.end():]
    if hostname:
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,252}", hostname):
            raise ValueError("Invalid hostname")
        secret = run("/usr/local/bin/mtg", "generate-secret", "--hex", hostname).stdout.strip()
        if not re.fullmatch(r"[0-9a-fA-F]+", secret):
            raise ValueError("Failed to generate MTG secret")
        text, count = re.subn(r'^secret\s*=\s*"[^"]*"', 'secret = "' + secret + '"', text, count=1, flags=re.M)
        if count != 1:
            raise ValueError("Missing MTG secret")
    changes = {new_config: (text.encode(), config.stat()),
               new_unit: unit_text.replace("/etc/mtg-" + old + ".toml", "/etc/mtg-" + new + ".toml")
                          .replace("(" + old + ")", "(" + new + ")").encode()}
    changes[new_unit] = (changes[new_unit], unit.stat())
    matches = []
    if old != new:
        for filename, key in (("profiles.json", "name"), ("client-info.json", "user")):
            path = root / "etc/tproxy-server" / filename
            if not path.exists():
                matches.append(0)
                continue
            document = json.loads(path.read_text())
            rows = document.get("profiles")
            if rows is None and filename == "client-info.json" and "user" in document:
                rows = [document]
            if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
                raise ValueError("Unsupported WebProxy profile format")
            if any(row.get(key) == new for row in rows):
                raise ValueError("WebProxy name already exists")
            found = [row for row in rows if row.get(key) == old]
            matches.append(len(found))
            if len(found) > 1:
                raise ValueError("Duplicate WebProxy name")
            if found:
                found[0][key] = new
                changes[path] = ((json.dumps(document, ensure_ascii=False, indent=2) + "\n").encode(), path.stat())
        if matches[0] != matches[1]:
            raise ValueError("WebProxy and client-info are inconsistent")
    return changes, [config, unit] if old != new else [], bool(matches and matches[0])


def edit(root, old, new, port, hostname=""):
    changes, removed, web_changed = prepare(root, old, new, port, hostname)
    before = {p: (p.read_bytes(), p.stat()) if p.exists() else None for p in set(changes) | set(removed)}
    backup_parent = root / "var/backups/mtproto-edit"
    backup_parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup = Path(tempfile.mkdtemp(prefix="edit-", dir=backup_parent))
    for path, snapshot in before.items():
        if snapshot:
            dest = backup / path.relative_to(root)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)
    old_unit, new_unit = "mtg-" + old + ".service", "mtg-" + new + ".service"
    active = run("systemctl", "is-active", "--quiet", old_unit, check=False).returncode == 0
    enabled = run("systemctl", "is-enabled", "--quiet", old_unit, check=False).returncode == 0
    relay_active = web_changed and run("systemctl", "is-active", "--quiet", "tproxy-server", check=False).returncode == 0
    traffic = root / "usr/local/bin/mtproto-traffic"
    if traffic.exists():
        run(str(traffic), "collect")
    try:
        for path, (data, metadata) in changes.items():
            atomic_write(path, data, metadata)
        if web_changed:
            run("/usr/local/bin/tproxy-server", "-check", "-config", "/etc/tproxy-server/config.json",
                "-profiles-file", "/etc/tproxy-server/profiles.json")
        run("systemctl", "stop", old_unit)
        if old != new:
            run("systemctl", "disable", old_unit)
        for path in removed:
            path.unlink()
        run("systemctl", "daemon-reload")
        if enabled:
            run("systemctl", "enable", new_unit)
        if active:
            run("systemctl", "start", new_unit)
            run("systemctl", "is-active", "--quiet", new_unit)
        if relay_active:
            run("systemctl", "restart", "tproxy-server")
            run("systemctl", "is-active", "--quiet", "tproxy-server")
        if traffic.exists():
            run(str(traffic), "sync")
    except Exception:
        rollback_ok = True
        for command in (("systemctl", "stop", new_unit), ("systemctl", "disable", new_unit)):
            run(*command, check=False)
        for path, snapshot in before.items():
            try:
                if snapshot:
                    atomic_write(path, *snapshot)
                else:
                    path.unlink(missing_ok=True)
            except OSError:
                rollback_ok = False
        commands = [("systemctl", "daemon-reload")]
        if enabled:
            commands.append(("systemctl", "enable", old_unit))
        if active:
            commands.append(("systemctl", "start", old_unit))
        if relay_active:
            commands.append(("systemctl", "restart", "tproxy-server"))
        if traffic.exists():
            commands.append((str(traffic), "sync"))
        for command in commands:
            if run(*command, check=False).returncode:
                rollback_ok = False
        raise RuntimeError(("Edit failed; rolled back. Backup: " if rollback_ok else
                            "Edit and rollback failed; restore backup: ") + str(backup))
    return backup


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("old")
    parser.add_argument("new")
    parser.add_argument("port", type=int)
    parser.add_argument("--hostname", default="")
    args = parser.parse_args()
    with open("/run/lock/mtproto-edit.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            backup = edit(Path("/"), args.old, args.new, args.port, args.hostname)
            print("Client updated. Backup: " + str(backup))
        except (OSError, ValueError, RuntimeError) as exc:
            print(str(exc))
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
