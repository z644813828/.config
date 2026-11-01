#!/usr/bin/env bash
set -euo pipefail

# Example only. Do not put secrets in this file.
#
# Uses the imported OMV migration image; persistent state remains inside it.

IMAGE="${IMAGE:-openclaw:migration}"
NAME="${NAME:-openclaw}"
SSH_PORT="${SSH_PORT:-2022}"
GATEWAY_PORT="${GATEWAY_PORT:-18789}"
NETWORK="${NETWORK:-infra_net}"
IP="${IP:-172.31.0.2}"

docker network inspect "$NETWORK" >/dev/null
if docker inspect "$NAME" >/dev/null 2>&1; then
  echo "STOP: existing container; preserve its writable-layer state before replacement" >&2
  exit 1
fi

docker run -d \
  --name "$NAME" \
  --restart unless-stopped \
  --workdir /root \
  --init \
  --pids-limit 256 \
  --network "$NETWORK" \
  --ip "$IP" \
  -p "192.168.2.254:${SSH_PORT}:22" \
  -p "127.0.0.1:${GATEWAY_PORT}:18789" \
  "$IMAGE" \
  bash -ec 'service ssh start; OPENCLAW_GATEWAY_TOKEN=$(node -e "const c=require(\"/root/.openclaw/openclaw.json\"); if (!c.gateway?.auth?.token) process.exit(1); process.stdout.write(c.gateway.auth.token)"); export OPENCLAW_GATEWAY_TOKEN; exec openclaw gateway run --port 18789 --bind lan --auth token'
