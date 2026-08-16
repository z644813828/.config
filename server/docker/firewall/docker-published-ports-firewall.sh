#!/usr/bin/env bash
set -euo pipefail

CHAIN="DOCKER-USER"

ALLOWED_SUBNETS=(
  "10.80.0.0/24"
  "192.168.1.0/24"
  "192.168.2.0/24"
  "192.168.10.0/24"
  "192.168.10.2/32"
  "172.30.0.1/32"
  "172.30.0.3/32"
)

RESTRICTED_SERVICES=(
  "openclaw:22"
  "openclaw:18789"
  "vpn-gateway:22"
  "rclone-cloud:22"
)

iptables -N "$CHAIN" 2>/dev/null || true

for rule_number in $(iptables -L "$CHAIN" --line-numbers | awk '/managed-by-docker-published-ports-firewall/ {print $1}' | sort -rn); do
  iptables -D "$CHAIN" "$rule_number"
done

for service in "${RESTRICTED_SERVICES[@]}"; do
  container="${service%%:*}"
  port="${service##*:}"
  container_ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || true)"

  if [ -n "$container_ip" ]; then
    iptables -I "$CHAIN" 1 -p tcp -d "$container_ip" --dport "$port" -j DROP -m comment --comment managed-by-docker-published-ports-firewall

    for subnet in "${ALLOWED_SUBNETS[@]}"; do
      iptables -I "$CHAIN" 1 -p tcp -s "$subnet" -d "$container_ip" --dport "$port" -j RETURN -m comment --comment managed-by-docker-published-ports-firewall
    done
  fi
done
