#!/usr/bin/env bash
# Start only a previously prepared Proxmox deployment, never replace a container.
set -euo pipefail
[[ $EUID -eq 0 && -d /etc/pve ]] || { echo 'STOP: Proxmox root required' >&2; exit 1; }
if docker inspect vpn-gateway >/dev/null 2>&1; then
  echo 'STOP: vpn-gateway already exists; do not replace a working VPN remotely' >&2
  exit 1
fi
STATE=/root/.backup-secrets/proxmox-vpn-gateway
for path in "$STATE/etc/wireguard/wg0.conf" "$STATE/root/.ssh/authorized_keys" \
    /opt/proxmox-vpn-gateway/start-host-forwards; do
  [[ -s "$path" ]] || { echo 'STOP: persistent gateway state is incomplete' >&2; exit 1; }
done
docker image inspect vpn-gateway:migration >/dev/null
[[ "$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}} {{.Gateway}}{{end}}' infra_net)" == '172.30.0.0/24 172.30.0.1' ]] || exit 1
[[ -c /dev/net/tun ]] || exit 1
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
docker compose -f "$HERE/docker-compose.yml" config --quiet
docker compose -f "$HERE/docker-compose.yml" up -d
