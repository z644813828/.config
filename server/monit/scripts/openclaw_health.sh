#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${OPENCLAW_CONTAINER:-openclaw}"

fail() {
    echo "CRITICAL: $*"
    exit 2
}

run_openclaw() {
    docker exec "$CONTAINER" openclaw "$@"
}

docker inspect "$CONTAINER" >/dev/null 2>&1 || fail "container not found: $CONTAINER"

[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER")" = "true" ] \
    || fail "container is not running: $CONTAINER"

health_output="$(run_openclaw health 2>&1)" || {
    printf '%s\n' "$health_output"
    fail "gateway health check failed"
}

model_output="$(run_openclaw models status 2>&1)" || {
    printf '%s\n' "$model_output"
    fail "cannot read model authentication status"
}

printf '%s\n' "$model_output" | grep -Fq 'status=usable' \
    || fail "OpenAI/Codex runtime authentication is not usable"

printf '%s\n' "$model_output" | grep -Eq '^  - openai:.*\bok\b' \
    || fail "no valid OpenAI OAuth profile is present"

version="$(run_openclaw --version 2>/dev/null || true)"
echo "OK: ${version}; gateway healthy; OpenAI/Codex OAuth is usable"
