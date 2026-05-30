#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-vpn-gateway-debian11-wireguard}"
NAME="${NAME:-vpn-gateway}"
SSH_PORT="${SSH_PORT:-2023}"

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
  -p "${SSH_PORT}:22" \
  "$IMAGE" \
  bash -lc 'service ssh start; /usr/local/bin/start-vpn-gateway; tail -f /dev/null'
