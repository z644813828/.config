#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-vpn-gateway-debian11-wireguard}"
NAME="${NAME:-vpn-gateway}"
SSH_PORT="${SSH_PORT:-2023}"
NETWORK="${NETWORK:-infra_net}"
SUBNET="${SUBNET:-172.30.0.0/24}"
GATEWAY="${GATEWAY:-172.30.0.1}"
IP="${IP:-172.30.0.3}"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create --subnet "$SUBNET" --gateway "$GATEWAY" "$NETWORK"

docker rm -f "$NAME" 2>/dev/null || true

docker run -d \
  --name "$NAME" \
  --restart unless-stopped \
  --init \
  --pids-limit 256 \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv4.ip_forward=1 \
  --network "$NETWORK" \
  --ip "$IP" \
  -p "${SSH_PORT}:22" \
  "$IMAGE" \
  bash -lc 'service ssh start; /usr/local/bin/start-vpn-gateway; tail -f /dev/null'
