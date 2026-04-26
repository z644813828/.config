#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
fi

DEFAULT_KEY_PATH="${MTPROTO_SSH_KEY_PATH:-../.ssh/vps}"
DEFAULT_HOST="${MTPROTO_SSH_HOST:-root@127.0.0.1}"

SSH_KEY_PATH="${SSH_KEY_PATH:-$DEFAULT_KEY_PATH}"
SSH_HOST="${SSH_HOST:-$DEFAULT_HOST}"
SSH_OPTS=(
  -i "$SSH_KEY_PATH"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
)

usage() {
  cat <<'EOF'
Usage:
  mtproto-cli.sh add <user_name> <port> [hostname_fqdn]
  mtproto-cli.sh remove <user_name>
  mtproto-cli.sh list
  mtproto-cli.sh status [user_name]
  mtproto-cli.sh access <user_name>
  mtproto-cli.sh traffic [user_name]

Environment overrides:
  SSH_HOST      Remote SSH target. Default: root@127.0.0.1
  SSH_KEY_PATH  SSH private key path. Default: ../.ssh/vps

Examples:
  ./mtproto-cli.sh add alexeyp 8444
  ./mtproto-cli.sh access dmitriy
  ./mtproto-cli.sh traffic
  ./mtproto-cli.sh list
EOF
}

require_ssh_key() {
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "SSH key not found: $SSH_KEY_PATH" >&2
    exit 1
  fi
}

remote_exec() {
  require_ssh_key
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" "$@"
}

cmd_add() {
  if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 add <user_name> <port> [hostname_fqdn]" >&2
    exit 1
  fi

  local remote_args=()
  local arg
  for arg in "$@"; do
    remote_args+=("$(printf '%q' "$arg")")
  done

  require_ssh_key
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" "bash -s -- ${remote_args[*]}" < "$SCRIPT_DIR/add-mtproto-user.sh"
}

cmd_remove() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 remove <user_name>" >&2
    exit 1
  fi

  local user_name="$1"
  remote_exec "set -e
if [[ -x /usr/local/bin/mtproto-traffic ]]; then
  /usr/local/bin/mtproto-traffic collect >/dev/null 2>&1 || true
fi
systemctl stop mtg-${user_name} >/dev/null 2>&1 || true
systemctl disable mtg-${user_name} >/dev/null 2>&1 || true
rm -f /etc/systemd/system/mtg-${user_name}.service
rm -f /etc/mtg-${user_name}.toml
systemctl daemon-reload
if [[ -x /usr/local/bin/mtproto-traffic ]]; then
  /usr/local/bin/mtproto-traffic forget ${user_name} >/dev/null 2>&1 || true
  /usr/local/bin/mtproto-traffic sync >/dev/null 2>&1 || true
  /usr/local/bin/mtproto-traffic collect >/dev/null 2>&1 || true
fi
echo \"Removed MTProto user: ${user_name}\""
}

cmd_list() {
  remote_exec 'set -e
for config in /etc/mtg-*.toml; do
  [[ -e "$config" ]] || continue
  user="${config#/etc/mtg-}"
  user="${user%.toml}"
  port="$(sed -n '\''s/^bind-to = "0.0.0.0:\([0-9]\+\)".*$/\1/p'\'' "$config")"
  service="mtg-${user}"
  state="$(systemctl is-active "$service" 2>/dev/null || true)"
  enabled="$(systemctl is-enabled "$service" 2>/dev/null || true)"
  printf "%-16s port=%-6s active=%-10s enabled=%s\n" "$user" "${port:-?}" "${state:-unknown}" "${enabled:-unknown}"
done'
}

cmd_status() {
  if [[ $# -gt 1 ]]; then
    echo "Usage: $0 status [user_name]" >&2
    exit 1
  fi

  if [[ $# -eq 0 ]]; then
    cmd_list
    return
  fi

  local user_name="$1"
  remote_exec "systemctl status mtg-${user_name} --no-pager -l"
}

cmd_access() {
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 access <user_name>" >&2
    exit 1
  fi

  local user_name="$1"
  remote_exec "/usr/local/bin/mtg access /etc/mtg-${user_name}.toml"
}

cmd_traffic() {
  if [[ $# -gt 1 ]]; then
    echo "Usage: $0 traffic [user_name]" >&2
    exit 1
  fi

  if [[ $# -eq 0 ]]; then
    remote_exec "/usr/local/bin/mtproto-traffic report"
    return
  fi

  local user_name="$1"
  remote_exec "/usr/local/bin/mtproto-traffic report $(printf '%q' "$user_name")"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local subcommand="$1"
  shift

  case "$subcommand" in
    add)
      cmd_add "$@"
      ;;
    remove)
      cmd_remove "$@"
      ;;
    list)
      cmd_list
      ;;
    status)
      cmd_status "$@"
      ;;
    access)
      cmd_access "$@"
      ;;
    traffic)
      cmd_traffic "$@"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      echo "Unknown command: $subcommand" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
