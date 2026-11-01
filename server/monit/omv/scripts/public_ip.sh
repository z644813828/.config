#!/bin/bash
set -Eeuo pipefail
umask 077
trap 'echo "ERROR: public IP check failed"; exit 2' ERR

STATE_DIR="${PUBLIC_IP_STATE_DIR:-/var/lib/monit/public-ip}"
mkdir -p "$STATE_DIR"
exec 9>"$STATE_DIR/lock"
flock -w 2 9

# Ignore proxy settings and curlrc so the proxy's public IP is not recorded.
if ! response=$(curl -q -4 --noproxy '*' --proxy '' -fsS \
    --connect-timeout 5 --max-time 15 https://api.ipify.org 2>/dev/null); then
    echo "ERROR: cannot obtain public IPv4 address"
    exit 2
fi

if ! current=$(printf '%s' "$response" | python3 -c '
import ipaddress, sys
try:
    address = ipaddress.IPv4Address(sys.stdin.read().strip())
    if not address.is_global:
        raise ValueError()
except ValueError:
    sys.exit(1)
print(address)
'); then
    echo "ERROR: invalid public IPv4 response"
    exit 2
fi

previous=""
if [ -f "$STATE_DIR/address" ]; then
    previous=$(<"$STATE_DIR/address")
fi

if [ "$previous" = "$current" ]; then
    echo "OK: public IPv4 unchanged: $current"
    exit 0
fi

TEMP=$(mktemp "$STATE_DIR/address.XXXXXX")
trap 'rm -f "$TEMP"' EXIT
printf '%s\n' "$current" > "$TEMP"
mv -f "$TEMP" "$STATE_DIR/address"

if [ -z "$previous" ]; then
    echo "OK: initial public IPv4 recorded: $current"
    exit 0
fi

echo "CHANGED: public IPv4: $previous -> $current"
exit 1
