#!/bin/bash

CONTAINER="vpn-gateway"

docker inspect "$CONTAINER" >/dev/null 2>&1 || {
    echo "Container $CONTAINER not found"
    exit 1
}

RUNNING=$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)
[ "$RUNNING" = "true" ] || {
    echo "Container $CONTAINER is not running"
    exit 1
}

docker exec "$CONTAINER" /usr/local/bin/check-vpn-gateway
