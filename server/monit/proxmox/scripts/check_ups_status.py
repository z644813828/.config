#!/usr/bin/env python3
"""Report UPS state to Monit without issuing UPS or shutdown commands."""
import subprocess


def evaluate(output):
    statuses = [line.partition(":")[2].strip()
                for line in output.splitlines()
                if line.partition(":")[0].strip() == "STATUS"]
    if len(statuses) != 1 or not statuses[0]:
        return 2, "ERROR: missing or ambiguous UPS STATUS"
    status = statuses[0]
    flags = set(status.split())
    if "ONLINE" in flags and flags <= {"ONLINE", "BOOST", "TRIM"}:
        return 0, f"OK: UPS status: {status}"
    return 1, f"ALERT: UPS status: {status}"


def main():
    try:
        result = subprocess.run(
            ["/sbin/apcaccess", "status", "127.0.0.1:3551"],
            capture_output=True, text=True, timeout=8, check=True,
        )
        code, message = evaluate(result.stdout)
    except (OSError, subprocess.SubprocessError, UnicodeError):
        code, message = 2, "ERROR: cannot read UPS state from local apcupsd"
    print(message)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
