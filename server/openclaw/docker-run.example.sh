#!/usr/bin/env bash
set -euo pipefail

# Example only. Do not put secrets in this file.
#
# Assumes an image was committed after OpenClaw/Codex/Telegram setup:
#   docker commit openclaw openclaw-debian11-codex-telegram

IMAGE="${IMAGE:-openclaw-debian11-codex-telegram}"
NAME="${NAME:-openclaw}"
SSH_PORT="${SSH_PORT:-2022}"
GATEWAY_PORT="${GATEWAY_PORT:-18789}"

docker run -d \
  --name "$NAME" \
  -p "${SSH_PORT}:22" \
  -p "${GATEWAY_PORT}:18789" \
  "$IMAGE" \
  bash -lc 'service ssh start 2>/dev/null || /usr/sbin/sshd; TOKEN=$(node -e "const c=require(\"/root/.openclaw/openclaw.json\"); console.log(c.gateway.auth.token)"); nohup env OPENCLAW_GATEWAY_TOKEN="$TOKEN" openclaw gateway run --port 18789 --bind lan --auth token --token "$TOKEN" >/root/.openclaw/logs/gateway.out 2>&1 & tail -f /dev/null'
