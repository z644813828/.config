#!/usr/bin/env python3
"""SATA temperature checks for the Proxmox host; notification state is Monit's."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import tempfile


LIMITS = {"warning": {True: 50, False: 60},
          "critical": {True: 55, False: 70}}


def json_command(command):
    result = subprocess.run(command, capture_output=True, text=True, timeout=10)
    document = json.loads(result.stdout)
    if not isinstance(document, dict):
        raise ValueError("invalid command output")
    return result.returncode, document


def temperature(document):
    value = document.get("temperature", {}).get("current")
    if type(value) is not int or not -20 <= value <= 150:
        raise ValueError("current temperature unavailable")
    return value


def evaluate(disk, code, document, previous, level):
    label = "{} {} [{}]".format(disk["path"], disk.get("model") or "disk",
                               disk.get("serial") or "no serial")
    limit = LIMITS[level][bool(disk["rota"])]
    mode = document.get("power_mode", {}).get("name", "")
    if code == 3 and mode in {"SLEEP", "STANDBY", "STANDBY_Y"}:
        # Sleeping does not prove that an earlier over-temperature has recovered.
        hot = previous is not None and previous >= limit
        return int(hot), f"{'ALERT' if hot else 'SKIP'} {label}: {mode}; last={previous}", previous
    if code & 7:
        return 2, f"ERROR {label}: smartctl exit={code}", previous
    current = temperature(document)
    hot = current >= limit
    return int(hot), f"{'ALERT' if hot else 'OK'} {label}: {current} C; limit={limit} C", current


def collect(level, state):
    code, inventory = json_command([
        "lsblk", "--json", "--nodeps", "--output", "PATH,TYPE,MODEL,SERIAL,ROTA,TRAN",
    ])
    if code:
        raise RuntimeError("lsblk failed")
    disks = [d for d in inventory.get("blockdevices", [])
             if d.get("type") == "disk" and d.get("tran") == "sata"]
    if not disks:
        raise RuntimeError("no SATA disks found")
    status = 0
    for disk in disks:
        key = disk.get("serial") or disk["path"]
        previous = state.get(key)
        try:
            code, document = json_command([
                "smartctl", "-j", "-d", "sat", "-n", "standby,3,5", "-A", disk["path"],
            ])
            result, message, last = evaluate(disk, code, document, previous, level)
            print(message)
            if last is not None:
                state[key] = last
            status = max(status, result)
        except (OSError, ValueError, TypeError, AttributeError, subprocess.SubprocessError):
            print(f"ERROR {disk['path']}: cannot read current temperature")
            status = 2
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--level", choices=LIMITS, default="warning")
    parser.add_argument("--state-dir", type=Path, default=Path("/var/lib/monit/disk-temperatures"))
    args = parser.parse_args()
    args.state_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = args.state_dir / (args.level + ".json")
    with (args.state_dir / (args.level + ".lock")).open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = json.loads(path.read_text()) if path.exists() else {}
        if not isinstance(state, dict) or any(type(t) is not int for t in state.values()):
            raise ValueError("invalid temperature cache")
        status = collect(args.level, state)
        fd, temporary = tempfile.mkstemp(dir=args.state_dir, prefix=args.level + ".")
        try:
            with os.fdopen(fd, "w") as output:
                json.dump(state, output)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return status


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, TypeError, AttributeError, RuntimeError, subprocess.SubprocessError):
        print("ERROR: temperature inventory or persistent state is unavailable")
        raise SystemExit(2)
