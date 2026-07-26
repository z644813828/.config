#!/bin/bash

MAX_HANDSHAKE_AGE_SECONDS=180
VPS_WG_IP="10.80.0.1"
PORTS="2222 80 443 445 548 5000 8880 18790 2812 4000 9091 199 8443 9443"

fail() {
    echo "$1"
    exit 1
}

handshake_age() {
    local latest now
    latest=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}' | sort -nr | head -n 1)
    [ -n "$latest" ] || return 1
    [ "$latest" -gt 0 ] 2>/dev/null || return 1
    now=$(date +%s)
    echo $((now - latest))
}

recover_wireguard() {
    echo "WireGuard handshake is unavailable; restarting vpn gateway"
    /usr/local/bin/stop-vpn-gateway
    sleep 2
    /usr/local/bin/start-vpn-gateway
    sleep 3
}

wg show wg0 >/dev/null 2>&1 || recover_wireguard
wg show wg0 >/dev/null 2>&1 || fail "WireGuard wg0 is not available"

# After a reboot the WireGuard peer may have no recorded handshake until the
# container sends the first packet. Wake the tunnel before checking timestamps.
ping -c 1 -W 2 "$VPS_WG_IP" >/dev/null 2>&1 || true

HANDSHAKE_AGE=$(handshake_age || true)
if [ -z "$HANDSHAKE_AGE" ] || [ "$HANDSHAKE_AGE" -gt "$MAX_HANDSHAKE_AGE_SECONDS" ]; then
    recover_wireguard
    ping -c 1 -W 2 "$VPS_WG_IP" >/dev/null 2>&1 || true
    HANDSHAKE_AGE=$(handshake_age || true)
fi

[ -n "$HANDSHAKE_AGE" ] || fail "WireGuard handshake is missing"
[ "$HANDSHAKE_AGE" -le "$MAX_HANDSHAKE_AGE_SECONDS" ] || fail "WireGuard handshake is stale: ${HANDSHAKE_AGE}s"

ping -c 1 -W 2 "$VPS_WG_IP" >/dev/null 2>&1 || fail "Cannot ping VPS WireGuard IP $VPS_WG_IP"

for PORT in $PORTS; do
    ss -ltn | grep -Eq "[[:space:]][^[:space:]]*:${PORT}[[:space:]]" \
        || fail "Port $PORT is not listening"
done

echo "VPN gateway is healthy. Latest handshake age: ${HANDSHAKE_AGE}s"
exit 0
