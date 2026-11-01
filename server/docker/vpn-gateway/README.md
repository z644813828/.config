# Proxmox WireGuard Gateway

Canonical permanent runtime files, moved out of migration on 2026-11-01.
The running gateway is on Proxmox, not inside OMV. The migration import scripts
remain in `../../migration/` for disaster recovery/bootstrap only.

## Current Layout

- Container/image: `vpn-gateway` / `vpn-gateway:migration`.
- Docker bridge: infra_net 172.30.0.0/24, gateway 172.30.0.1, container 172.30.0.3.
- WireGuard address: 10.80.0.10; LAN host: 192.168.2.250; OMV: 192.168.2.254.
- Protected WG/SSH state: `/root/.backup-secrets/proxmox-vpn-gateway/`.
- Bind-mounted container forwards stub: `/opt/proxmox-vpn-gateway/start-host-forwards`.
- Host relay script/unit: `proxmox-gateway-relays.sh` / `proxmox-gateway-relays.service`.

The imported container's old socat failed on the new kernel. The host's socat
and libraries run with `nsenter -n` in the container network namespace instead.
The stub deliberately starts no in-container socat processes. The unit monitors
container PID and child relays and restarts when the namespace changes.
Do not run both the old listeners and the host relay service.

The relay template includes Proxmox SSH 2222/HTTPS 8006, OMV services and ASUS
8443. TeamSpeak is intentionally not forwarded over WG. Only ports 2222/8006
are required by the current Monit VPN check; do not infer all template ports are
deployed. Review the actual /opt script and client connectivity before updates.

## Updating Files, Not Replacing The Gateway

Transfer the three runtime files to `/root` on Proxmox. With an independent LAN
console available and after reviewing the port mappings:

```bash
install -d -m 700 /opt/proxmox-vpn-gateway
install -m 700 /root/proxmox-gateway-relays.sh /opt/proxmox-vpn-gateway/
install -m 644 /root/proxmox-gateway-relays.service /etc/systemd/system/
# Keep the existing bind inode; replacing it atomically leaves Docker on the old file.
cp /root/start-host-forwards /opt/proxmox-vpn-gateway/start-host-forwards
systemctl daemon-reload
systemctl restart proxmox-gateway-relays.service
```

Restarting relays interrupts established proxied sessions. Keep a separate host
access path and test SSH, HTTPS and WireGuard afterwards. Repository moves do not
change installed /opt or unit paths and require no live restart by themselves.

## Recreating A Lost Container

`docker-compose.yml` describes the prepared Proxmox runtime with persistent WG
and SSH bind mounts, LAN-only gateway SSH 2023 and no Docker socket mount.
`docker-run.sh` validates the host, existing state/image/network and refuses any
existing container. It no longer forcibly removes containers. Use it only after
reviewing a recovery plan and recording the live Docker inventory. Never run a
second gateway using the same WireGuard keys.

The current running container was created with docker run during migration;
adding a Compose project here does not adopt or rename it. Do not replace a
working gateway just to match the repository. Preserve writable-layer changes
and all secret mounts before any container replacement. The imported image also
contains secrets and must be backed up privately, not pushed to a registry.

Back up the unit, /opt scripts, protected state and exact image as part of host
recovery. See [VPN monitoring](../../monit/proxmox/VPN.md).
