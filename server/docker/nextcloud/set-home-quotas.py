#!/usr/bin/env python3
"""Set a 1 GB home quota for existing accounts and the default for new ones."""
import json
import subprocess


def occ(*args, capture=False):
    return subprocess.run(
        ["docker", "exec", "--user", "www-data", "nextcloud", "php", "occ", *args],
        check=True, text=True, stdout=subprocess.PIPE if capture else None,
    ).stdout


def main():
    users = json.loads(occ("user:list", "--output=json", capture=True))
    if not isinstance(users, dict) or not users:
        raise SystemExit("STOP: unexpected or empty account list")
    occ("config:system:set", "quota_include_external_storage", "--type=boolean", "--value=false")
    occ("config:app:set", "files", "default_quota", "--value=1 GB")
    for user in users:
        occ("user:setting", user, "files", "quota", "1 GB")
        value = occ("user:setting", user, "files", "quota", capture=True).strip()
        if value != "1 GB":
            raise SystemExit(f"STOP: quota verification failed for {user}")
        print(f"{user}: {value}", flush=True)


if __name__ == "__main__":
    main()
