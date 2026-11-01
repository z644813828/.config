#!/usr/bin/env bash
set -u

ENV_FILE="${OMV_STATUS_ENV_FILE:-/var/www/server-home/.env}"
OUTPUT_FILE="${OMV_STATUS_OUTPUT_FILE:-/var/lib/monit/server-home/service-status.json}"
TMP_FILE="${OUTPUT_FILE}.$$"
trap 'rm -f -- "$TMP_FILE"' EXIT
mkdir -p "$(dirname "$OUTPUT_FILE")" || exit 1

if [ -r "$ENV_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [ -z "$line" ] && continue
        [ "${line#\#}" != "$line" ] && continue

        key="${line%%=*}"
        value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        case "$key" in
            OMV_*) export "$key=$value" ;;
        esac
    done < "$ENV_FILE"
fi

json_escape() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/	/\\t/g'
}

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

tcp_check() {
    local host="$1"
    local port="$2"
    timeout 2 bash -c ":</dev/tcp/${host}/${port}" >/dev/null 2>&1
}

http_check() {
    local url="$1"
    curl -kfsS --max-time 4 "$url" >/dev/null 2>&1
}

systemd_active() {
    local unit="$1"
    systemctl is-active --quiet "$unit" >/dev/null 2>&1
}

unit_or_process_active() {
    local unit="$1"
    local process="$2"

    if command -v systemctl >/dev/null 2>&1 && systemctl cat "$unit" >/dev/null 2>&1; then
        systemd_active "$unit"
        return $?
    fi

    pgrep -x "$process" >/dev/null 2>&1
}

status_line() {
    local key="$1"
    local state="$2"
    local message="$3"
    local details="$4"

    if [ "${STATUS_FIRST:-1}" -eq 1 ]; then
        STATUS_FIRST=0
    else
        printf ',\n'
    fi

    printf '    "%s": {"status": "%s", "message": "%s", "details": "%s", "checked_at": "%s"}' \
        "$(json_escape "$key")" \
        "$(json_escape "$state")" \
        "$(json_escape "$message")" \
        "$(json_escape "$details")" \
        "$(now_utc)"
}

check_openmediavault() {
    if http_check "https://127.0.0.1:8444/"; then
        status_line "openmediavault" "ok" "web UI is responding" "127.0.0.1:8444"
    elif systemd_active nginx; then
        status_line "openmediavault" "warn" "nginx is running, web UI is not responding" "check php-fpm/openmediavault"
    else
        status_line "openmediavault" "down" "nginx is not running" "systemctl status nginx"
    fi
}

check_3x_ui() {
    local count="${OMV_3XUI_PANELS:-0}"
    local ok=0
    local total=0
    local url
    local i

    if [ "$count" -gt 0 ] 2>/dev/null; then
        for i in $(seq 1 "$count"); do
            eval "url=\${OMV_3XUI_PANEL_${i}_URL:-}"
            [ -z "$url" ] && continue
            total=$((total + 1))
            if http_check "$url"; then
                ok=$((ok + 1))
            fi
        done
    elif [ -n "${OMV_3XUI_PANEL_URL:-}" ]; then
        total=1
        if http_check "$OMV_3XUI_PANEL_URL"; then
            ok=1
        fi
    fi

    if [ "$total" -eq 0 ]; then
        status_line "3x-ui" "unknown" "panels are not configured" "OMV_3XUI_PANELS"
    elif [ "$ok" -eq "$total" ]; then
        status_line "3x-ui" "ok" "panels are reachable" "${ok}/${total}"
    elif [ "$ok" -gt 0 ]; then
        status_line "3x-ui" "warn" "some panels are unreachable" "${ok}/${total}"
    else
        status_line "3x-ui" "down" "panels are not responding" "0/${total}"
    fi
}

check_tcp_service() {
    local key="$1"
    local name="$2"
    local host="$3"
    local port="$4"

    if tcp_check "$host" "$port"; then
        status_line "$key" "ok" "$name is responding" "${host}:${port}"
    else
        status_line "$key" "down" "$name is not responding" "${host}:${port}"
    fi
}

check_url_or_tcp_service() {
    local key="$1"
    local name="$2"
    local url="$3"
    local fallback_host="$4"
    local fallback_port="$5"

    if [ -n "$url" ] && [ "$url" != "#" ]; then
        if http_check "$url"; then
            status_line "$key" "ok" "$name is responding" "configured endpoint"
        else
            status_line "$key" "down" "$name is not responding" "configured endpoint"
        fi
        return
    fi

    if [ -n "$fallback_host" ] && [ -n "$fallback_port" ]; then
        check_tcp_service "$key" "$name" "$fallback_host" "$fallback_port"
    else
        status_line "$key" "unknown" "$name is not configured" "remote URL is empty"
    fi
}

check_monit() {
    if systemd_active monit && curl -fsS --max-time 4 \
        --unix-socket /run/monit.sock http://localhost/ >/dev/null 2>&1; then
        status_line "monit" "ok" "Monit is running" "/run/monit.sock"
    elif systemd_active monit; then
        status_line "monit" "warn" "Monit service is running, HTTP interface is unavailable" "/run/monit.sock"
    else
        status_line "monit" "down" "Monit service is not running" "systemctl status monit"
    fi
}

check_teamspeak() {
    if ss -lun 2>/dev/null | awk '{print $5}' | grep -Eq '(^|:)9987$'; then
        status_line "teamspeak" "ok" "UDP port is listening" "9987/udp"
    elif tcp_check 127.0.0.1 10011; then
        status_line "teamspeak" "ok" "ServerQuery is responding" "10011/tcp"
    else
        status_line "teamspeak" "unknown" "could not reliably check UDP service" "9987/udp"
    fi
}

check_apcupsd() {
    local state message
    local helper="$(dirname -- "${BASH_SOURCE[0]}")/ups_snapshot.py"
    local snapshot="${OMV_UPS_STATUS_FILE:-/var/lib/monit/server-home/ups-status.json}"
    if ! IFS=$'\t' read -r state message < <(python3 "$helper" status --file "$snapshot" 2>/dev/null); then
        state=unknown
        message="Proxmox UPS snapshot is unavailable"
    fi
    case "$state" in
        ok|warn|down|unknown) ;;
        *) state=unknown; message="Proxmox UPS snapshot is invalid" ;;
    esac
    status_line "apcupsd" "$state" "$message" "Proxmox UPS snapshot"
}

check_streamdeck() {
    if [ -e "/var/www/server-home/arduino/index.php" ]; then
        status_line "streamdeck" "ok" "local page exists" "arduino/index.php"
    else
        status_line "streamdeck" "unknown" "local page was not found" "arduino/index.php"
    fi
}

check_nextcloud() {
    local state=down
    local message="Nextcloud status endpoint is unavailable"
    if curl -fsS --max-time 4 http://127.0.0.1:8081/status.php | \
        python3 -c 'import json, sys; c=json.load(sys.stdin); sys.exit(not (c.get("installed") is True and c.get("maintenance") is False and c.get("needsDbUpgrade") is False))' \
        >/dev/null 2>&1; then
        state=ok
        message="Nextcloud is installed and ready"
    fi
    status_line "nextcloud" "$state" "$message" "127.0.0.1:8081/status.php"
    # Keep the existing portal tile working until it is renamed.
    status_line "filebrowser" "$state" "$message" "replaced by Nextcloud"
}

{
    printf '{\n'
    printf '  "generated_at": "%s",\n' "$(now_utc)"
    printf '  "services": {\n'
    STATUS_FIRST=1
    check_openmediavault
    check_3x_ui
    check_nextcloud
    check_tcp_service "proxmox" "Proxmox HTTPS listener" 192.168.2.250 8006
    check_tcp_service "openclaw" "OpenClaw" 127.0.0.1 18790
    check_tcp_service "vaultwarden" "Vaultwarden" 127.0.0.1 9443
    check_tcp_service "gitlab" "Gitlab" 127.0.0.1 9444
    check_monit
    check_tcp_service "asus-router" "Asus router" 192.168.2.1 8443
    check_url_or_tcp_service "keenetic-router" "Keenetic router" "${OMV_KEENETIC_REMOTE_URL:-}" "" ""
    check_tcp_service "transmission" "Transmission" 127.0.0.1 9091
    check_teamspeak
    check_apcupsd
    if [ "${OMV_CHECK_STREAMDECK:-false}" = true ]; then
        check_streamdeck
    fi
    printf '\n'
    printf '  }\n'
    printf '}\n'
} > "$TMP_FILE"

if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$TMP_FILE" >/dev/null || {
        rm -f "$TMP_FILE"
        exit 1
    }
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
mv "$TMP_FILE" "$OUTPUT_FILE"
chmod 0644 "$OUTPUT_FILE"
