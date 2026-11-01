#!/usr/bin/env python3
"""Grant Nextcloud access without unmasking other ACL principals' permissions."""
import argparse
import os
from pathlib import Path
import pwd
import stat
import subprocess
import tempfile
import re


BASE = Path("/srv/dev-disk-by-uuid-eb9e73fb-a8b9-4216-829e-7469929e5c31")


def bits(text):
    return sum(bit for char, bit in zip(text, (4, 2, 1)) if char != "-")


def permissions(value):
    return "".join(char if value & bit else "-" for char, bit in zip("rwx", (4, 2, 1)))


def parse_acl(text):
    result = {}
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        key, value = line.rsplit(":", 1)
        if len(value) != 3 or any(c not in "rwx-" for c in value):
            raise ValueError("unrecognized ACL entry")
        result[key] = bits(value)
    return result


def grant(entries, uid, is_directory, executable):
    result = dict(entries)
    prefixes = ("", "default:") if is_directory else ("",)
    for prefix in prefixes:
        group = prefix + "group:"
        mask_key = prefix + "mask:"
        if group not in result:
            if not prefix:
                raise ValueError("missing access ACL")
            result.update({prefix + "user:": 7, group: 0, prefix + "other:": 0})
        old_mask = result.get(mask_key, result[group])
        for key in list(result):
            local = key[len(prefix):] if key.startswith(prefix) else ""
            if (not prefix and key.startswith("default:")) or not key.startswith(prefix):
                continue
            if local.startswith("group:") or (local.startswith("user:") and local != "user:"):
                result[key] &= old_mask
        requested = 7 if prefix or is_directory or executable else 6
        key = prefix + "user:33"
        result[key] = result.get(key, 0) | requested
        if prefix:
            result[prefix + "user:" + str(uid)] = 7
        new_mask = 0
        for key, value in result.items():
            if not key.startswith(prefix) or (not prefix and key.startswith("default:")):
                continue
            local = key[len(prefix):]
            if local.startswith("group:") or (local.startswith("user:") and local != "user:"):
                new_mask |= value
        result[mask_key] = new_mask
    return result


def command(arguments, **kwargs):
    return subprocess.run(arguments, check=True, text=True, **kwargs)


def walk(root):
    device = root.stat().st_dev
    def fail(error):
        raise error
    for directory, directories, files in os.walk(root, followlinks=False, onerror=fail):
        parent = Path(directory)
        if parent.stat().st_dev != device:
            raise ValueError("nested filesystem: " + str(parent))
        yield parent
        for name in files:
            path = parent / name
            if not path.is_symlink():
                yield path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("users", nargs="+", help="explicit personal Linux usernames")
    args = parser.parse_args()
    if any(not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", u) for u in args.users):
        raise ValueError("invalid Linux username")
    if os.geteuid() != 0 or not BASE.is_mount():
        raise ValueError("run as root on OMV with UserData mounted")
    roots = []
    for user in dict.fromkeys(args.users):
        account = pwd.getpwnam(user)
        if account.pw_uid < 1000 or account.pw_uid == 65534:
            raise ValueError("refusing a system account")
        root = BASE / user
        if root.is_symlink() or not root.is_dir() or root.stat().st_uid != account.pw_uid:
            raise ValueError("unexpected owner or directory: " + str(root))
        roots.append((root, account.pw_uid))
    backup = Path(tempfile.mkdtemp(prefix="nextcloud-acl-", dir="/root"))
    with (backup / "before.acl").open("w") as output:
        command(["getfacl", "-R", "-P", "-p", "-n", *[str(r) for r, _ in roots]], stdout=output)
    print("ACL backup:", backup / "before.acl", flush=True)
    for root, uid in roots:
        count = 0
        for path in walk(root):
            metadata = path.lstat()
            if not (stat.S_ISREG(metadata.st_mode) or stat.S_ISDIR(metadata.st_mode)):
                continue
            text = command(["getfacl", "-c", "-n", "-p", "--", str(path)],
                           capture_output=True).stdout
            before = parse_acl(text)
            after = grant(before, uid, stat.S_ISDIR(metadata.st_mode), bool(metadata.st_mode & 0o111))
            if after != before:
                spec = ",".join(f"{key}:{permissions(value)}" for key, value in after.items())
                command(["setfacl", "-n", "-m", spec, "--", str(path)])
            count += 1
            if count % 1000 == 0:
                print(root.name, "checked:", count, flush=True)
        print("OK:", root, "entries:", count, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        raise SystemExit("STOP: " + str(error)) from None
