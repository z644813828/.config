#!/usr/bin/env python3
"""Fetch a read-only UPS snapshot by pinned SSH or summarize the local cache."""
import argparse
from datetime import datetime, timezone
import grp
import json
import os
from pathlib import Path
import subprocess
import tempfile


DEFAULT_FILE = Path("/var/lib/monit/server-home/ups-status.json")


def validate(document, now=None):
    if (not isinstance(document, dict) or type(document.get("schema")) is not int
            or document["schema"] != 1 or document.get("source") != "proxmox"):
        raise ValueError("invalid UPS snapshot")
    stamp = datetime.fromisoformat(document["generated_at"])
    if stamp.tzinfo is None:
        raise ValueError("timestamp has no timezone")
    age = ((now or datetime.now(timezone.utc)) - stamp).total_seconds()
    if age < -30 or age > 180:
        raise ValueError("UPS snapshot is stale or from the future")
    values = document.get("values")
    if not isinstance(values, dict) or not values.get("STATUS") or len(values) > 32:
        raise ValueError("invalid UPS fields")
    for key, value in values.items():
        if (not isinstance(key, str) or not key.isupper() or not key.isalnum()
                or not isinstance(value, str) or not value or len(value) > 256 or not value.isprintable()):
            raise ValueError("invalid UPS value")
    return document


def summary(document):
    values = validate(document)["values"]
    status = values["STATUS"]
    flags = set(status.split())
    state = "ok" if "ONLINE" in flags and flags <= {"ONLINE", "BOOST", "TRIM"} else "warn"
    if "COMMLOST" in flags:
        state = "down"
    return state, f"UPS {status}; battery: {values.get('BCHARGE', '?')}; runtime: {values.get('TIMELEFT', '?')}"


def fetch():
    result = subprocess.run([
        "/usr/bin/ssh", "-F", "/dev/null", "-T", "-x",
        "-i", "/etc/monit/ssh/ups-readonly",
        "-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes",
        "-o", "IdentityAgent=none", "-o", "ClearAllForwardings=yes",
        "-o", "ConnectTimeout=5", "-o", "ConnectionAttempts=1",
        "-o", "StrictHostKeyChecking=yes",
        "-o", "UserKnownHostsFile=/etc/monit/ssh/ups-known-hosts",
        "-o", "GlobalKnownHostsFile=/dev/null",
        "root@192.168.2.250", "ups-status",
    ], capture_output=True, text=True, timeout=15, check=True)
    if len(result.stdout) > 16384:
        raise ValueError("oversized UPS response")
    return validate(json.loads(result.stdout))


def save(path, document, gid):
    validate(document)
    # A root:www-data setgid directory supplies the group without CAP_CHOWN.
    fd, name = tempfile.mkstemp(prefix=".ups-status.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            if os.fstat(output.fileno()).st_gid != gid:
                raise OSError("snapshot directory must inherit the reader group")
            os.fchmod(output.fileno(), 0o640)
            json.dump(document, output)
            output.write("\n")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("fetch", "status"))
    parser.add_argument("--file", type=Path, default=DEFAULT_FILE)
    args = parser.parse_args()
    try:
        if args.mode == "fetch":
            save(args.file, fetch(), grp.getgrnam("www-data").gr_gid)
            print("OK: Proxmox UPS snapshot updated")
        else:
            print("\t".join(summary(json.loads(args.file.read_text()))))
        return 0
    except (OSError, ValueError, KeyError, TypeError, UnicodeError, subprocess.SubprocessError):
        if args.mode == "status":
            print("unknown\tProxmox UPS snapshot is missing, stale or invalid")
        else:
            print("ERROR: cannot refresh UPS snapshot; check pinned SSH access and local permissions")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
