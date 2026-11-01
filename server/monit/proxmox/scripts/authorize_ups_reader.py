#!/usr/bin/env python3
"""Append one restricted UPS-reader key, preserving Proxmox authorized_keys."""
import os
from pathlib import Path
import subprocess
import tempfile


OPTIONS = 'from="192.168.2.254",restrict,command="/usr/local/sbin/export-ups-status.py"'


def entry(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if len(lines) != 1:
        raise ValueError("expected one public key")
    parts = lines[0].split()
    if len(parts) < 2 or parts[0] != "ssh-ed25519":
        raise ValueError("expected a plain Ed25519 public key")
    return f"{OPTIONS} {parts[0]} {parts[1]} omv-ups-readonly", parts[1]


def authorize(public, authorized, backup_root):
    line, key = entry(public.read_text())
    subprocess.run(["/usr/bin/ssh-keygen", "-lf", str(public)],
                   capture_output=True, check=True, timeout=5)
    if not authorized.is_file():
        raise ValueError("existing authorized_keys file required")
    original = authorized.read_bytes()
    matches = [item.strip() for item in original.decode().splitlines() if key in item.split()]
    if matches:
        if all(item == line for item in matches):
            return None
        raise ValueError("key already exists with different restrictions; inspect manually")
    backup = Path(tempfile.mkdtemp(prefix="ups-authorized-keys-before.", dir=backup_root))
    fd = os.open(backup / "authorized_keys", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "wb") as output:
        output.write(original)
    # Append through any existing /etc/pve symlink; do not replace or chmod it.
    with authorized.open("ab") as output:
        if original and not original.endswith(b"\n"):
            output.write(b"\n")
        output.write((line + "\n").encode())
    return backup


def main():
    if os.geteuid() != 0:
        raise SystemExit("STOP: run as root on Proxmox")
    if not Path("/etc/pve").is_dir() or not Path("/usr/local/sbin/export-ups-status.py").is_file():
        raise SystemExit("STOP: Proxmox or installed UPS exporter not found")
    try:
        backup = authorize(Path("/root/ups-readonly.pub"),
                           Path("/root/.ssh/authorized_keys"), Path("/root"))
    except ValueError as error:
        raise SystemExit(f"STOP: {error}") from None
    except (OSError, UnicodeError, subprocess.SubprocessError):
        raise SystemExit("STOP: cannot install restricted UPS key") from None
    if backup:
        print(f"OK: restricted UPS key installed; original keys saved in {backup}")
    else:
        print("OK: the same restricted UPS key is already installed")


if __name__ == "__main__":
    main()
