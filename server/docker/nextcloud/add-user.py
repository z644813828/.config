#!/usr/bin/env python3
"""Provision a personal OMV/HDD/Nextcloud account locally; plan unless --apply."""
import argparse
import fcntl
import getpass
import importlib.util
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import sys
import tempfile
import time


HERE = Path(__file__).resolve().parent


def load(name, filename):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


storage = load("storage", "configure-personal-storage.py")
BASE = Path(storage.USERDATA)
DATA = Path(storage.DATA)
STATE = Path("/var/lib/omv-personal-users")


def command(*args, input_text=None):
    result = subprocess.run(args, input=input_text, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{Path(args[0]).name} failed (exit {result.returncode}); output withheld")
    return result.stdout


def omv_create(user, password):
    # Same remote RPC entry point as omv-rpc, but the secret arrives over stdin.
    php = r'''
    require_once "openmediavault/autoloader.inc";
    require_once "openmediavault/globals.inc";
    require_once "openmediavault/functions.inc";
    try {
        $p = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR);
        \OMV\Rpc\Rpc::call("UserMgmt", "setUser", $p, [
            "username" => \OMV\Environment::get("OMV_WEBGUI_ADMINUSER_NAME", "admin"),
            "role" => OMV_ROLE_ADMINISTRATOR
        ], \OMV\Rpc\Rpc::MODE_REMOTE);
    } catch (\Throwable $e) { exit(1); }
    '''
    params = {"name": user, "groups": [], "shell": "/bin/bash", "password": password,
              "email": "", "comment": "", "disallowusermod": False, "sshpubkeys": []}
    command("php", "-c", "/etc/openmediavault", "-r", php, input_text=json.dumps(params))


def nextcloud_create(user, password):
    php = r'''
    $password = stream_get_contents(STDIN);
    putenv("OC_PASS=" . $password);
    $argv = ["occ", "user:add", "--password-from-env", $argv[1]];
    $argc = count($argv);
    require "/var/www/html/occ";
    '''
    command("docker", "exec", "-i", "--user", "www-data", "nextcloud",
            "php", "-r", php, user, input_text=password)


def atomic_json(path, value):
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".user-")
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(value, output, ensure_ascii=False, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def bindings(document, user):
    result = json.loads(json.dumps(document))
    if set(result) - {"services"}:
        raise ValueError("unexpected fields in personal bind override")
    services = result.setdefault("services", {})
    if set(services) - {"app", "cron"}:
        raise ValueError("unexpected service in bind override")
    for name in ("app", "cron"):
        service = services.setdefault(name, {"volumes": []})
        if set(service) != {"volumes"}:
            raise ValueError("unexpected service settings in bind override")
        volumes = service["volumes"]
        target = f"/external/{user}"
        for volume in volumes:
            username = volume.get("target", "").removeprefix("/external/")
            storage.usernames([username])
            expected = {"type": "bind", "source": str(BASE / username),
                        "target": f"/external/{username}", "read_only": False,
                        "bind": {"create_host_path": False}}
            if volume != expected:
                raise ValueError("unexpected bind override; inspect it locally")
        if not any(v["target"] == target for v in volumes):
            volumes.append({"type": "bind", "source": str(BASE / user), "target": target,
                            "read_only": False, "bind": {"create_host_path": False}})
    return result


def backup_policy(path):
    text = path.read_text()
    literal_source = any(source in text for source in
                         (str(BASE) + "/", "/srv/dev-disk-by-label-UserData/"))
    variable_source = (re.search(r'^USERDATA="' + re.escape(str(BASE)) + r'"$', text, re.M)
                       and '"$USERDATA/"' in text)
    if "rsync" not in text or not (literal_source or variable_source):
        raise ValueError("cannot find UserData rsync source; review the backup script first")
    cron = command("crontab", "-l")
    if not any(not line.lstrip().startswith("#") and str(path) in line for line in cron.splitlines()):
        raise ValueError("daily backup script not found in root crontab")
    return any(option in text for option in ("--exclude", "--filter", "--files-from", "--include"))


def account(user):
    try:
        return pwd.getpwnam(user)
    except KeyError:
        return None


def owned_directory(path, uid):
    if path.is_symlink() or not path.is_dir() or path.stat().st_uid != uid:
        raise ValueError("unexpected directory or owner: " + str(path))


def fresh_directory(path, uid, gid):
    if path.exists() or path.is_symlink():
        owned_directory(path, uid)
        return
    path.mkdir(mode=0o700)
    # Remove inherited ACLs on this NEW empty directory, never on existing data.
    command("setfacl", "-b", "-k", "--", str(path))
    os.chown(path, uid, gid)
    path.chmod(0o700)


def run(args):
    user = storage.usernames([args.user])[0]
    if os.geteuid() != 0 or not Path("/etc/openmediavault/config.xml").is_file():
        raise ValueError("run locally as root on OMV")
    for path in (BASE, DATA):
        if not path.is_mount():
            raise ValueError("required HDD is not mounted: " + str(path))
    for binary in ("php", "docker", "setfacl", "getfacl", "omv-salt", "crontab", "omv-rpc"):
        if not shutil.which(binary):
            raise ValueError("missing executable: " + binary)
    compose = Path(args.compose).resolve(strict=True)
    if compose.is_relative_to(Path("/root")) or compose.parent != DATA / "docker/compose/nextcloud":
        raise ValueError("expected the live Nextcloud Compose file on Data")
    override = compose.with_name("compose.personal-binds.json")
    if override.is_symlink():
        raise ValueError("bind override must not be a symlink")
    previous = json.loads(override.read_text()) if override.exists() else {}
    document = bindings(previous, user)
    backup_filters = backup_policy(Path(args.backup_script))
    accounts = json.loads(storage.occ("nextcloud", "user:list", "--output=json"))
    existing = json.loads(storage.occ("nextcloud", "files_external:list", "--output=json"))
    # Require the already configured shared mounts before making any account.
    storage.plan(existing, [user])
    quota_external = json.loads(storage.occ(
        "nextcloud", "config:system:get", "quota_include_external_storage", "--output=json"))
    if quota_external is not False:
        raise ValueError("set quota_include_external_storage=false before provisioning")
    root = BASE / user
    checkpoint = STATE / (user + ".json")
    record = json.loads(checkpoint.read_text()) if checkpoint.exists() else None
    current = account(user)
    if args.resume:
        if not record or record.get("user") != user:
            raise ValueError("no provisioning checkpoint for --resume")
    elif record or current or user in accounts or root.exists() or root.is_symlink():
        raise ValueError("name already exists; only --resume of this CLI's checkpoint is allowed")
    if current:
        if current.pw_uid < 1000 or current.pw_uid == 65534:
            raise ValueError("refusing system account")
        if record.get("uid") is not None and record["uid"] != current.pw_uid:
            raise ValueError("UID changed since provisioning")
    settings = json.loads(command("omv-rpc", "UserMgmt", "getSettings", "{}"))
    if settings.get("enable"):
        raise ValueError("OMV relocates home directories globally; review settings first")
    print(f"PLAN: OMV user {user}; private HDD root {root}; eight desktop directories")
    print("PLAN: Nextcloud non-admin, home quota 1GB; ten scoped external mounts")
    print("PLAN: shared OS/Software read-only unless an existing explicit write grant exists")
    print("BACKUP: UserData rsync source and root cron entry found")
    if backup_filters:
        print(f"WARNING: backup script contains filters; manually verify coverage of {root}")
    print("NOTE: source/cron detection does not prove user coverage or a completed backup")
    if not args.apply:
        print("PLAN ONLY: use --apply. app/cron will be recreated; Nextcloud briefly unavailable.")
        return
    if not record:
        record = {"user": user, "created": int(time.time()), "uid": None}
    password = None
    if current is None or user not in accounts:
        if not sys.stdin.isatty():
            raise ValueError("use an interactive terminal for the hidden password prompt")
        password = getpass.getpass("Password for the new OMV/Nextcloud account: ")
        if not password or any(c in password for c in ("\n", "\r", "\x00")):
            raise ValueError("empty or multiline password")
        if password != getpass.getpass("Repeat password: "):
            raise ValueError("passwords differ")
    STATE.mkdir(mode=0o700, exist_ok=True)
    atomic_json(checkpoint, record)
    if current is None:
        omv_create(user, password)
        current = pwd.getpwnam(user)
    record["uid"] = current.pw_uid
    atomic_json(checkpoint, record)
    home = Path(current.pw_dir)
    if home != Path("/home") / user:
        raise ValueError("OMV home is not /home/USERNAME; review global home settings")
    fresh_directory(home, current.pw_uid, current.pw_gid)
    fresh_directory(root, current.pw_uid, current.pw_gid)
    for folder in storage.FOLDERS:
        fresh_directory(root / folder, current.pw_uid, current.pw_gid)
        link = home / folder
        if not link.exists() and not link.is_symlink():
            link.symlink_to(root / folder)
            os.lchown(link, current.pw_uid, current.pw_gid)
        elif not link.is_symlink() or os.readlink(link) != str(root / folder):
            raise ValueError("home path collision; nothing replaced: " + str(link))
    command("python3", str(HERE / "grant-personal-access.py"), user)
    if override.exists():
        saved = STATE / f"binds-before-{time.time_ns()}.json"
        atomic_json(saved, previous)
    atomic_json(override, document)
    compose_cmd = ("docker", "compose", "-f", str(compose), "-f", str(override))
    command(*compose_cmd, "config", "--quiet")
    command(*compose_cmd, "up", "-d", "--no-deps", "app", "cron")
    for attempt in range(30):
        try:
            status = json.loads(storage.occ("nextcloud", "status", "--output=json"))
            if status.get("installed") and not status.get("maintenance"):
                break
        except (RuntimeError, ValueError):
            pass
        time.sleep(2)
    else:
        raise ValueError("Nextcloud did not become ready after container recreation")
    for container in ("nextcloud", "nextcloud-cron"):
        mounts = json.loads(command("docker", "inspect", container))[0]["Mounts"]
        storage.validate_bindings(mounts, [user])
    if user not in accounts:
        nextcloud_create(user, password)
    password = None
    storage.occ("nextcloud", "user:setting", user, "files", "quota", "1GB")
    quota = storage.occ("nextcloud", "user:setting", user, "files", "quota").strip()
    if quota.replace(" ", "") != "1GB":
        raise ValueError("Nextcloud home quota verification failed")
    command("python3", str(HERE / "configure-personal-storage.py"), user,
            "--replace-root-folders", "--apply")
    storage.occ("nextcloud", "files:scan", user)
    # Deploy only user-related OMV services, not the entire appliance config.
    command("omv-salt", "deploy", "run", "samba")
    record["complete"] = True
    atomic_json(checkpoint, record)
    print("OK: user provisioned. Test Linux/Samba credentials, Nextcloud login, isolation and uploads.")
    print("No SMB share was created; adding a share is a separate explicit operation.")
    print("Use BOTH -f files for future Compose operations: " + str(override))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("user")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--resume", action="store_true", help="continue this CLI's partial provision")
    parser.add_argument("--compose", default=str(DATA / "docker/compose/nextcloud/docker-compose.yml"))
    parser.add_argument("--backup-script", default="/srv/dev-disk-by-uuid-87c841a9-8d9a-4b8c-96aa-6ea6da074aad/_/backup-daily.sh")
    args = parser.parse_args()
    os.umask(0o077)
    with open("/run/omv-personal-users.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        run(args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        if isinstance(error, (ValueError, RuntimeError)):
            print("Reason:", str(error))
        raise SystemExit("STOP: no automatic deletion/rollback. Correct the cause; use --resume only if a checkpoint exists. Secret-bearing command output was withheld.") from None
