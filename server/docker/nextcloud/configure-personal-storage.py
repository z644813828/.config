#!/usr/bin/env python3
"""Plan or import scoped Local mounts; never delete mounts or move user files."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import re


FOLDERS = ("Видео", "Документы", "Загрузки", "Изображения", "Музыка",
           "Общедоступные", "Рабочий стол", "Шаблоны")
USERDATA = "/srv/dev-disk-by-uuid-eb9e73fb-a8b9-4216-829e-7469929e5c31"
DATA = "/srv/dev-disk-by-uuid-9c6424ec-3918-4b89-8eb5-043ecb0f5ebf"
SHARED = {"Software": "/external/_Software", "OS": "/external/OS"}


def run(command, input_text=None, stage=None):
    result = subprocess.run(command, input=input_text, text=True, capture_output=True)
    if result.returncode:
        # Do not dump Docker config or errors that might contain credentials.
        raise RuntimeError(f"{stage or command[0]} failed (exit {result.returncode})")
    return result.stdout


def occ(container, *arguments, input_text=None):
    return run(["docker", "exec", "-i", "--user", "www-data", container,
                "php", "occ", *arguments], input_text, stage="occ " + arguments[0])


def check_container_paths(container, paths, writable=False, absent=False,
                          allow_directory_shadowing=False):
    probe = r'''
        $result = [];
        foreach (json_decode($argv[1], true, 512, JSON_THROW_ON_ERROR) as $p) {
            $result[] = ['path' => $p, 'exists' => file_exists($p) || is_link($p), 'link' => is_link($p),
                'directory' => is_dir($p), 'readable' => is_readable($p),
                'writable' => is_writable($p), 'searchable' => is_executable($p)];
        }
        echo json_encode($result, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
    '''
    result = json.loads(run([
        "docker", "exec", "--user", "www-data", container,
        "php", "-r", probe, json.dumps(paths, ensure_ascii=False),
    ], stage="container filesystem probe"))
    failures = []
    shadowed = []
    for item in result:
        if absent:
            if (item["exists"] and allow_directory_shadowing
                    and item.get("directory") and not item.get("link")):
                shadowed.append(item["path"])
                reason = ""
            else:
                reason = "already exists; new mount would hide it" if item["exists"] else ""
        elif not item["exists"]:
            reason = "directory is missing (or a parent directory is inaccessible)"
        elif not item["directory"]:
            reason = "not a directory"
        else:
            required = ["readable", "searchable"] + (["writable"] if writable else [])
            reason = ", ".join("not " + k for k in required if not item[k])
        if reason:
            failures.append(item["path"] + ": " + reason)
    if failures:
        raise ValueError("filesystem preflight:\n" + "\n".join(failures))
    return shadowed


def applies(mount, user):
    users = mount.get("applicable_users", [])
    groups = mount.get("applicable_groups", [])
    return user in users or bool(groups) or not (users or groups)


def make_mount(user, folder, path, exemplar, readonly=False):
    return {
        "mount_id": None,
        "mount_point": "/" + folder,
        "storage": exemplar["storage"],
        "authentication_type": exemplar["authentication_type"],
        "configuration": {"datadir": path},
        "options": {"readonly": readonly, "enable_sharing": True,
                    "filesystem_check_changes": 1, "previews": True},
        "applicable_users": [user], "applicable_groups": [],
    }


def usernames(values):
    if not values or any(not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", v) for v in values):
        raise ValueError("specify Linux usernames explicitly")
    return tuple(dict.fromkeys(values))


def plan(existing, users):
    exemplars = [m for m in existing
                 if m.get("configuration", {}).get("datadir") in SHARED.values()]
    if not exemplars:
        raise ValueError("existing Software/OS Local mount is required as a schema reference")
    exemplar = exemplars[0]
    desired = []
    for user in usernames(users):
        for name in FOLDERS:
            desired.append(make_mount(user, name, f"/external/{user}/{name}", exemplar))
        for name, source in SHARED.items():
            # Retain already configured write access. Newly granted access is read-only.
            writers = [m for m in existing
                       if m.get("configuration", {}).get("datadir") == source
                       and user in m.get("applicable_users", [])
                       and m.get("options", {}).get("readonly", False) is False]
            desired.append(make_mount(user, "Общедоступные/" + name, source,
                                      exemplar, readonly=not bool(writers)))

    pending = []
    for candidate in desired:
        user = candidate["applicable_users"][0]
        matches = [m for m in existing
                   if m["mount_point"] == candidate["mount_point"] and applies(m, user)]
        if not matches:
            pending.append(candidate)
            continue
        if len(matches) != 1:
            raise ValueError(f"overlapping mounts: {user} {candidate['mount_point']}")
        old = matches[0]
        if (old.get("storage") != candidate["storage"]
                or old.get("authentication_type") != candidate["authentication_type"]
                or old.get("applicable_users") != [user]
                or old.get("applicable_groups")
                or old.get("configuration", {}).get("datadir") != candidate["configuration"]["datadir"]
                or old.get("options", {}).get("readonly", False) != candidate["options"]["readonly"]
                or old.get("options", {}).get("enable_sharing", False) is not True):
            raise ValueError(f"conflicting existing mount: {user} {candidate['mount_point']}")
    return desired, pending


def validate_bindings(mounts, users):
    expected = {f"/external/{u}": f"{USERDATA}/{u}" for u in usernames(users)}
    expected.update({"/external/OS": f"{DATA}/Software/OS",
                     "/external/_Software": f"{DATA}/Software/_Software"})
    for destination, source in expected.items():
        actual = [m for m in mounts if m.get("Destination") == destination]
        if (len(actual) != 1 or actual[0].get("Type") != "bind"
                or actual[0].get("Source") != source):
            raise ValueError(f"missing or unexpected Docker bind: {source} -> {destination}")
        if destination in {f"/external/{u}" for u in users} and not actual[0].get("RW"):
            raise ValueError(f"personal Docker bind must be writable: {destination}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("users", nargs="+", help="explicit personal Linux/Nextcloud usernames")
    parser.add_argument("--container", default="nextcloud")
    parser.add_argument("--apply", action="store_true", help="import new mounts after preflight")
    parser.add_argument("--replace-root-folders", action="store_true",
                        help="allow new mounts to hide existing primary-home directories; never delete their contents")
    args = parser.parse_args()
    users = usernames(args.users)
    print("CHECK: Nextcloud accounts", flush=True)
    accounts = json.loads(occ(args.container, "user:list", "--output=json"))
    missing = set(users) - set(accounts)
    if missing:
        raise ValueError("create Nextcloud accounts first: " + ", ".join(sorted(missing)))
    print("CHECK: Docker bind mounts", flush=True)
    container = json.loads(run(["docker", "inspect", args.container], stage="Docker inspect"))[0]
    validate_bindings(container["Mounts"], users)
    existing = json.loads(occ(args.container, "files_external:list", "--output=json"))
    desired, pending = plan(existing, users)
    personal_paths = [m["configuration"]["datadir"] for m in desired
                      if m["configuration"]["datadir"] not in SHARED.values()]
    # Readable files with no directory search permission are insufficient.
    print("CHECK: personal directory permissions", flush=True)
    check_container_paths(args.container, personal_paths, writable=True)
    print("CHECK: shared directory permissions", flush=True)
    check_container_paths(args.container, list(SHARED.values()))
    data_directory = occ(args.container, "config:system:get", "datadirectory").strip()
    # Only explicit consent permits shadowing primary-home directories.
    primary_paths = []
    nested_paths = []
    for mount in pending:
        user = mount["applicable_users"][0]
        if "/" not in mount["mount_point"].lstrip("/"):
            primary_paths.append(f"{data_directory}/{user}/files{mount['mount_point']}")
        else:
            nested_paths.append(f"/external/{user}{mount['mount_point']}")
    shadowed = []
    if primary_paths:
        print("CHECK: files that would be hidden by new mounts", flush=True)
        shadowed = check_container_paths(
            args.container, primary_paths, absent=True,
            allow_directory_shadowing=args.replace_root_folders)
        for path in shadowed:
            print("REPLACE VIEW ONLY (original directory retained on disk):", path)
    if nested_paths:
        check_container_paths(args.container, nested_paths, absent=True)
    for mount in pending:
        print(mount["applicable_users"][0], mount["mount_point"], "->",
              mount["configuration"]["datadir"],
              "RO" if mount["options"]["readonly"] else "RW")
    print(f"Existing desired mounts: {len(desired) - len(pending)}; new: {len(pending)}")
    if not pending:
        return
    payload = json.dumps(pending, ensure_ascii=False)
    print("CHECK: Nextcloud import dry-run", flush=True)
    occ(args.container, "files_external:import", "--dry", "-", input_text=payload)
    if not args.apply:
        print("PLAN ONLY: use --apply after reviewing; no mounts changed")
        return
    if os.geteuid() != 0:
        raise ValueError("run --apply as root on OMV")
    backup = Path(tempfile.mkdtemp(prefix="nextcloud-mounts-", dir="/root"))
    (backup / "before.json").write_text(json.dumps(existing, ensure_ascii=False, indent=2))
    (backup / "import.json").write_text(json.dumps(pending, ensure_ascii=False, indent=2))
    (backup / "shadowed-directories.json").write_text(json.dumps(shadowed, ensure_ascii=False, indent=2))
    print("Backup:", backup)
    occ(args.container, "files_external:import", "-", input_text=payload)
    after = json.loads(occ(args.container, "files_external:list", "--output=json"))
    _, remaining = plan(after, users)
    if remaining:
        raise ValueError("import incomplete; inspect mounts before retrying")
    print(f"OK: all {len(desired)} scoped mounts exist. Legacy mounts and user files preserved.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, TypeError, KeyError, RuntimeError) as error:
        raise SystemExit("STOP: " + str(error)) from None
