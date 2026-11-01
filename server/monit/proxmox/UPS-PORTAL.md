# Read-Only UPS Data For The OMV Portal

NIS stays bound to 127.0.0.1:3551 on Proxmox. OMV polls a restricted SSH command
over the existing LAN SSH port; no new network listener is introduced. The web
worker reads only a local cached JSON file, never the SSH key or Docker socket.
Do not expose NIS on 0.0.0.0 or grant general root SSH access to the polling key.

## Proxmox Exporter

Install `scripts/export_ups_status.py` root:root mode 0750 as
`/usr/local/sbin/export-ups-status.py`. Test it locally. Its fixed apcaccess
command is read-only and returns a small JSON document with a UTC timestamp.
Only selected UPS fields are exported; hostnames and serial numbers are omitted.
It ignores client-supplied commands and does not execute SSH_ORIGINAL_COMMAND.

## Dedicated Key And Host Pinning

On OMV create `/etc/monit/ssh` root:root 0700. Generate a new Ed25519 key
`ups-readonly` there, without a passphrase for unattended polling; do not reuse
an administrator key and never copy the private key off OMV. Transfer only its
`.pub` file to Proxmox outside the repository.

Append a line to Proxmox root's authorized_keys preserving all existing entries:

The supplied `scripts/authorize_ups_reader.py` installs this restriction from
`/root/ups-readonly.pub`, after validating the key with ssh-keygen. It creates
a private backup of existing entries and appends through an existing symlink.
It refuses an already-present copy of the key with different restrictions;
repeating the identical restricted installation is a no-op.

```text
from="192.168.2.254",restrict,command="/usr/local/sbin/export-ups-status.py" ssh-ed25519 PUBLIC_KEY_FROM_OMV omv-ups-readonly
```

Do not install the same key without the options above. `restrict` disables PTY,
agent, port and X11 forwarding and user rc files; the forced command replaces
shell, SFTP, SCP and arbitrary command requests. The source address restriction
accepts only OMV. On Proxmox authorized_keys may be a symlink into /etc/pve:
preserve that symlink, back up the target content and append rather than replacing.
No SSH daemon restart or relaxation of PermitRootLogin is required for standard
key-based root access. Confirm the existing root-key policy before installation.

Obtain Proxmox's Ed25519 SSH host-key fingerprint from its trusted console.
On OMV scan that key to a temporary candidate file, compare fingerprints via
the trusted session, and only then install `/etc/monit/ssh/ups-known-hosts`
root:root 0600. Do not trust ssh-keyscan alone or disable host-key checking.

## OMV Cache And Monit

Install `../omv/scripts/ups_snapshot.py` root:root 0750 into `/etc/monit/scripts/`.
Provision `/var/lib/monit/server-home` root:www-data mode 2750 (setgid, no group
write). Existing OMV status setup grants www-data traversal of /var/lib/monit;
verify this rather than granting broad access. The fetcher atomically creates
root:www-data 0640 files using the directory's group inheritance, so Monit needs
no new capability. The root-only SSH directory is outside ProtectHome's /root.

Run `python3 /etc/monit/scripts/ups_snapshot.py fetch` manually, then install
`../omv/conf.d/ups-snapshot.conf`. Validate and reload Monit. At a 30-second
daemon interval snapshots refresh every minute. Failed SSH reads retain the
last snapshot but both consumers reject it after three minutes. Monit alerts
after three failed refreshes; power-state alerts remain on Proxmox to avoid
depending on the guest for UPS safety.

## Portal

Install the updated OMV `service_status_collect.sh` and the updated
`../../web/apcupsd.php` without overwriting private .env files. The collector
reads the snapshot for the APC tile's status; it never connects to Proxmox.
The PHP endpoint reads the same file with a strict age limit, returns 503 for
missing/stale/invalid data and cannot run shell commands. Its JavaScript uses
native fetch and textContent, not the missing legacy jQuery dependency.

Add only the exact `/apcupsd.php` PHP location from
`../../web/server-home.nginx.conf`, including the existing IP allowlist. Preserve
the ACME and HTTPS configuration. Other arbitrary PHP scripts remain disabled.
Check nginx -t and reload; verify both authorized access and rejection from an
untrusted source, and test page refresh on desktop/mobile. The state file is
outside the document root, not a public JSON endpoint.

## Verification Status

Local parser, cache, collector, PHP and browser tests cover stale/future snapshots,
errors, restricted SSH flags, privacy filtering and desktop/mobile rendering.
The user confirmed exporter/key provisioning, host-fingerprint comparison,
pinned SSH polling from OMV, Monit polling and www-data read access to the cache.
The user subsequently confirmed the live APC page and portal integration work.
The source remains a local-only NIS endpoint on Proxmox; OMV reads it through
the restricted SSH exporter. An actual outage/shutdown exercise is still
deferred until backups are available.

Reference: https://man.openbsd.org/sshd.8#AUTHORIZED_KEYS_FILE_FORMAT
