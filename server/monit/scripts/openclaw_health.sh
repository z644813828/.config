#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${OPENCLAW_CONTAINER:-openclaw}"
STATE_DIR="${OPENCLAW_HEALTH_STATE_DIR:-/var/lib/monit/openclaw-health}"
REFRESH_INTERVAL=3600

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
    fail "gateway health check failed"
}

model_output="$(run_openclaw models status --json 2>/dev/null)" || {
    fail "cannot read model authentication status"
}

# Exit 3 requests an active gateway check: access tokens can expire while the
# refresh token remains usable. Plain models status does not refresh them.
validate_auth() {
printf '%s\n' "$model_output" | docker exec -i "$CONTAINER" node -e '
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
        const profiles = ((auth.oauth || {}).profiles || []).filter(p => p.provider === "openai" && p.type === "oauth");
        if (!profiles.length) reject("no OpenAI OAuth profile is present");
        const valid = profiles.some(p =>
            ["ok", "expiring"].includes(p.status) &&
            Number.isFinite(p.expiresAt) && p.expiresAt > Date.now());
        if (!valid) process.exit(3);
    } catch (_) {
        reject("cannot parse model authentication status");
    }
});
'
}

if auth_result="$(validate_auth)"; then
    :
else
    auth_status=$?
    [ "$auth_status" -eq 3 ] || fail "${auth_result:-cannot validate model authentication status}"

    # Persist the attempt BEFORE calling the model, including failed/time-out
    # attempts. A lock also prevents parallel Monit/manual checks spending quota.
    [[ "$CONTAINER" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || fail "invalid container name"
    umask 077
    mkdir -p "$STATE_DIR" || fail "cannot create OAuth check state directory"
    exec 9>"$STATE_DIR/$CONTAINER.lock" || fail "cannot open OAuth check lock"
    flock -n 9 || fail "OAuth refresh check is already running"
    attempt_file="$STATE_DIR/$CONTAINER.last-attempt"
    now="$(date +%s)"
    if [ -e "$attempt_file" ]; then
        last_attempt="$(cat "$attempt_file")" || fail "cannot read OAuth check timestamp"
        [[ "$last_attempt" =~ ^[1-9][0-9]{0,11}$ ]] || fail "invalid OAuth check timestamp"
        remaining=$((REFRESH_INTERVAL - (now - last_attempt)))
        if [ "$remaining" -gt 0 ]; then
            fail "OAuth access token expired; next gateway refresh attempt in ${remaining}s (hourly limit)"
        fi
    fi
    printf '%s\n' "$now" >"$attempt_file.tmp" \
        && mv -f "$attempt_file.tmp" "$attempt_file" \
        || fail "cannot persist OAuth check timestamp"

    # No --deliver: the diagnostic reply is never sent to Telegram. A normal
    # gateway turn lets the active runtime refresh its credentials safely.
    timeout 35 docker exec "$CONTAINER" openclaw agent \
        --session-id monit-oauth-healthcheck \
        --message 'Reply with exactly: AUTH_OK. Do not use tools.' \
        --thinking off --timeout 25 --json >/dev/null 2>&1 \
        || fail "OAuth access token expired; gateway refresh check failed or timed out"
    model_output="$(run_openclaw models status --json 2>/dev/null)" \
        || fail "cannot read model authentication status after refresh"
    if auth_result="$(validate_auth)"; then
        :
    else
        fail "${auth_result:-OpenAI OAuth token remains expired after gateway check}"
    fi
fi

version="$(run_openclaw --version 2>/dev/null || true)"
echo "OK: ${version}; gateway healthy; OpenAI/Codex OAuth is usable"
