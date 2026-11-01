#!/usr/bin/python3
"""Export a sanitized UPS snapshot for a restricted SSH forced command."""
from datetime import datetime, timezone
import json
import subprocess


FIELDS = {
    "MODEL", "STATUS", "LINEV", "LOADPCT", "BCHARGE", "TIMELEFT", "MBATTCHG",
    "MINTIMEL", "MAXTIME", "BATTV", "BATTDATE", "SELFTEST", "NOMINV",
    "NOMBATTV", "NOMPOWER", "LASTXFER", "NUMXFERS", "TONBATT", "CUMONBATT",
}


def snapshot(output):
    values = {}
    for line in output.splitlines():
        key, separator, value = line.partition(":")
        key, value = key.strip(), value.strip()
        if separator and key in FIELDS:
            if key in values or not value or len(value) > 256 or not value.isprintable():
                raise ValueError("invalid UPS field")
            values[key] = value
    if "STATUS" not in values:
        raise ValueError("missing UPS status")
    return {"schema": 1, "source": "proxmox",
            "generated_at": datetime.now(timezone.utc).isoformat(), "values": values}


def main():
    try:
        result = subprocess.run(
            ["/sbin/apcaccess", "status", "127.0.0.1:3551"],
            capture_output=True, text=True, timeout=5, check=True,
        )
        print(json.dumps(snapshot(result.stdout), ensure_ascii=True))
        return 0
    except (OSError, ValueError, UnicodeError, subprocess.SubprocessError):
        print(json.dumps({"error": "UPS status unavailable"}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
