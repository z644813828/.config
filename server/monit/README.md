# Monit By Host

- [OMV](omv/README.md): NAS applications, backups, certificates and network checks.
- [Proxmox](proxmox/README.md): host UPS, SATA temperatures and Docker VPN gateway.

Each host has its own `conf.d/` and `scripts/`. Deploy only reviewed files to
the corresponding host's `/etc/monit/conf.d/` and `/etc/monit/scripts/`; deployed
paths do not change. Do not copy an entire host directory into the other host.
Tests live beside the scripts they exercise and are not deployment files.

Checker filenames omit the host name because the parent directory identifies
the target. Globally scoped identifiers (container names, AppArmor profiles,
systemd units and Docker volumes) are not renamed by this convention.
