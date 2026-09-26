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

model_output="$(run_openclaw models status --json 2>/dev/null)" || {
    fail "cannot read model authentication status"
}

# Use the container's Node.js; expiring access tokens are still valid and may
# be refreshed by OpenClaw. Ignore unrelated stale profiles in the same store.
if auth_result="$(printf '%s\n' "$model_output" | docker exec -i "$CONTAINER" node -e '
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", chunk => { input += chunk; });
process.stdin.on("end", () => {
    function reject(message) { console.log(message); process.exit(2); }
    try {
        const auth = JSON.parse(input).auth;
        const routes = auth.runtimeAuthRoutes || [];
        if (!routes.some(r => r.provider === "openai" && r.runtime === "codex" && r.status === "usable")) {
            reject("OpenAI/Codex runtime authentication is not usable");
        }
        const profiles = (auth.oauth || {}).profiles || [];
        const valid = profiles.some(p => p.provider === "openai" && p.type === "oauth" &&
            ["ok", "expiring"].includes(p.status) &&
            Number.isFinite(p.expiresAt) && p.expiresAt > Date.now());
        if (!valid) reject("no unexpired OpenAI OAuth profile is present");
    } catch (_) {
        reject("cannot parse model authentication status");
    }
});
')"; then
    :
else
    fail "${auth_result:-cannot validate model authentication status}"
fi

version="$(run_openclaw --version 2>/dev/null || true)"
echo "OK: ${version}; gateway healthy; OpenAI/Codex OAuth is usable"
