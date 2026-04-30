#!/bin/bash

MAX_HANDSHAKE_AGE_SECONDS=180
VPS_WG_IP="10.80.0.1"
PORTS="2222 80 443 445 548 5000 8880 18790 2812 4000 9091 199 8443"

fail() {
    echo "$1"
    exit 1
}

wg show wg0 >/dev/null 2>&1 || fail "WireGuard wg0 is not available"

LATEST_HANDSHAKE=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}' | sort -nr | head -n 1)
[ -n "$LATEST_HANDSHAKE" ] || fail "WireGuard handshake is missing"
[ "$LATEST_HANDSHAKE" -gt 0 ] 2>/dev/null || fail "WireGuard handshake is zero"

NOW=$(date +%s)
HANDSHAKE_AGE=$((NOW - LATEST_HANDSHAKE))
[ "$HANDSHAKE_AGE" -le "$MAX_HANDSHAKE_AGE_SECONDS" ] || fail "WireGuard handshake is stale: ${HANDSHAKE_AGE}s"

ping -c 1 -W 2 "$VPS_WG_IP" >/dev/null 2>&1 || fail "Cannot ping VPS WireGuard IP $VPS_WG_IP"

for PORT in $PORTS; do
    ss -ltn | grep -Eq "[[:space:]][^[:space:]]*:${PORT}[[:space:]]" \
        || fail "Port $PORT is not listening"
done

echo "VPN gateway is healthy. Latest handshake age: ${HANDSHAKE_AGE}s"
exit 0
