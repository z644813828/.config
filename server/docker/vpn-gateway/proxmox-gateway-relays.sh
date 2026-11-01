#!/usr/bin/env bash
# Proxmox host socat and libraries, gateway network namespace. Managed by systemd.
set -Eeuo pipefail
get_pid() {
    docker inspect -f '{{if .State.Running}}{{.State.Pid}}{{end}}' vpn-gateway 2>/dev/null
}
PID="$(get_pid)"
[[ "$PID" =~ ^[1-9][0-9]*$ ]] || exit 1
PIDS=()
cleanup() {
    if (( ${#PIDS[@]} )); then
        kill "${PIDS[@]}" 2>/dev/null || true
        wait "${PIDS[@]}" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 0' TERM INT

# Listen port : destination host : destination port.
# Only restored services are enabled; SMB, Monit HTTP API and others come later.
for mapping in \
    2222:172.30.0.1:22 \
    8006:172.30.0.1:8006 \
    80:192.168.2.254:80 \
    443:192.168.2.254:443 \
    8444:192.168.2.254:8444 \
    9443:192.168.2.254:9443 \
    9091:192.168.2.254:9091 \
    18790:192.168.2.254:18790 \
    2022:192.168.2.254:2022 \
    2024:192.168.2.254:2024 \
    8443:192.168.2.1:8443; do
    IFS=: read -r listen_port destination_host destination_port <<< "$mapping"
    nsenter -t "$PID" -n /usr/bin/socat -d -d \
        "TCP4-LISTEN:${listen_port},bind=10.80.0.10,reuseaddr,fork" \
        "TCP4:${destination_host}:${destination_port}" &
    PIDS+=("$!")
done

# A relay retains the old namespace after container restart. Restart the service
# when Docker gives gateway a new PID, or either listener fails.
while sleep 2; do
    [[ "$(get_pid)" == "$PID" ]] || exit 1
    for child in "${PIDS[@]}"; do
        kill -0 "$child" 2>/dev/null || exit 1
        state="$(ps -o stat= -p "$child")" || exit 1
        [[ "$state" != Z* ]] || exit 1
    done
done
