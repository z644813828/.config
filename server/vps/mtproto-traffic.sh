#!/usr/bin/env bash

set -euo pipefail

CHAIN_IN="MTPROTO_TRAFFIC_IN"
CHAIN_OUT="MTPROTO_TRAFFIC_OUT"
STATE_DIR="/var/lib/mtproto-traffic"
LAST_FILE="${STATE_DIR}/last.tsv"
TOTALS_FILE="${STATE_DIR}/totals.tsv"
MONTH_FILE="${STATE_DIR}/month.tsv"
MONTH_MARKER_FILE="${STATE_DIR}/month.marker"

usage() {
  cat <<'EOF'
Usage:
  mtproto-traffic sync
  mtproto-traffic collect
  mtproto-traffic report [user_name]
  mtproto-traffic report-tsv [user_name]
  mtproto-traffic report-month [user_name]
  mtproto-traffic report-month-tsv [user_name]
  mtproto-traffic bootstrap-month
  mtproto-traffic forget <user_name>
EOF
}

ensure_dependencies() {
  command -v iptables >/dev/null 2>&1 || {
    echo "iptables not found" >&2
    exit 1
  }
  command -v iptables-save >/dev/null 2>&1 || {
    echo "iptables-save not found" >&2
    exit 1
  }
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR"
  touch "$LAST_FILE" "$TOTALS_FILE" "$MONTH_FILE"
  if [[ ! -f "$MONTH_MARKER_FILE" ]]; then
    date +%Y-%m > "$MONTH_MARKER_FILE"
  fi
}

list_users() {
  local config user port
  for config in /etc/mtg-*.toml; do
    [[ -e "$config" ]] || continue
    user="${config#/etc/mtg-}"
    user="${user%.toml}"
    port="$(sed -n 's/^bind-to = "0\.0\.0\.0:\([0-9]\+\)".*$/\1/p' "$config" | head -n 1)"
    [[ -n "$port" ]] || continue
    printf '%s\t%s\n' "$user" "$port"
  done | sort
}

human_bytes() {
  local bytes="${1:-0}"
  if command -v numfmt >/dev/null 2>&1; then
    if (( bytes < 1024 )); then
      printf '%s B\n' "$bytes"
    else
      numfmt --to=iec --suffix=B --format='%.2f' "$bytes" | sed 's/iB$/B/'
    fi
    return
  fi
  printf '%s B\n' "$bytes"
}

save_totals_snapshot() {
  declare -A cur_in=()
  declare -A cur_out=()
  declare -A last_in=()
  declare -A last_out=()
  declare -A total_in=()
  declare -A total_out=()
  declare -A month_in=()
  declare -A month_out=()
  declare -A seen=()

  ensure_state_dir

  local current_month stored_month
  current_month="$(date +%Y-%m)"
  stored_month="$(cat "$MONTH_MARKER_FILE" 2>/dev/null || true)"
  if [[ "$stored_month" != "$current_month" ]]; then
    : > "$MONTH_FILE"
    printf '%s\n' "$current_month" > "$MONTH_MARKER_FILE"
  fi

  while IFS=$'\t' read -r user in_bytes out_bytes; do
    [[ -n "$user" ]] || continue
    total_in["$user"]="${in_bytes:-0}"
    total_out["$user"]="${out_bytes:-0}"
    seen["$user"]=1
  done < "$TOTALS_FILE"

  while IFS=$'\t' read -r user in_bytes out_bytes; do
    [[ -n "$user" ]] || continue
    last_in["$user"]="${in_bytes:-0}"
    last_out["$user"]="${out_bytes:-0}"
    seen["$user"]=1
  done < "$LAST_FILE"

  while IFS=$'\t' read -r user in_bytes out_bytes; do
    [[ -n "$user" ]] || continue
    month_in["$user"]="${in_bytes:-0}"
    month_out["$user"]="${out_bytes:-0}"
    seen["$user"]=1
  done < "$MONTH_FILE"

  while IFS=$'\t' read -r user direction bytes; do
    [[ -n "$user" ]] || continue
    if [[ "$direction" == "in" ]]; then
      cur_in["$user"]="$bytes"
    else
      cur_out["$user"]="$bytes"
    fi
    seen["$user"]=1
  done < <(
    iptables-save -c | sed -n 's/^\[[0-9]\+:\([0-9]\+\)\] -A MTPROTO_TRAFFIC_[A-Z_]\+.*--comment "mtproto:\([^":]\+\):\(in\|out\)".*/\2\t\3\t\1/p'
  )

  local user cur prev delta
  for user in "${!seen[@]}"; do
    if [[ -v cur_in["$user"] ]]; then
      cur="${cur_in[$user]}"
      prev="${last_in[$user]:-0}"
      if (( cur >= prev )); then
        delta=$(( cur - prev ))
      else
        delta=$cur
      fi
      total_in["$user"]=$(( ${total_in[$user]:-0} + delta ))
      month_in["$user"]=$(( ${month_in[$user]:-0} + delta ))
      last_in["$user"]="$cur"
    else
      last_in["$user"]=0
      total_in["$user"]="${total_in[$user]:-0}"
      month_in["$user"]="${month_in[$user]:-0}"
    fi

    if [[ -v cur_out["$user"] ]]; then
      cur="${cur_out[$user]}"
      prev="${last_out[$user]:-0}"
      if (( cur >= prev )); then
        delta=$(( cur - prev ))
      else
        delta=$cur
      fi
      total_out["$user"]=$(( ${total_out[$user]:-0} + delta ))
      month_out["$user"]=$(( ${month_out[$user]:-0} + delta ))
      last_out["$user"]="$cur"
    else
      last_out["$user"]=0
      total_out["$user"]="${total_out[$user]:-0}"
      month_out["$user"]="${month_out[$user]:-0}"
    fi
  done

  : > "$TOTALS_FILE"
  : > "$LAST_FILE"
  : > "$MONTH_FILE"
  for user in $(printf '%s\n' "${!seen[@]}" | sort); do
    printf '%s\t%s\t%s\n' \
      "$user" \
      "${total_in[$user]:-0}" \
      "${total_out[$user]:-0}" >> "$TOTALS_FILE"
    printf '%s\t%s\t%s\n' \
      "$user" \
      "${last_in[$user]:-0}" \
      "${last_out[$user]:-0}" >> "$LAST_FILE"
    printf '%s\t%s\t%s\n' \
      "$user" \
      "${month_in[$user]:-0}" \
      "${month_out[$user]:-0}" >> "$MONTH_FILE"
  done
}

ensure_chains() {
  iptables -N "$CHAIN_IN" 2>/dev/null || true
  iptables -N "$CHAIN_OUT" 2>/dev/null || true

  iptables -C INPUT -p tcp -j "$CHAIN_IN" 2>/dev/null || iptables -I INPUT 1 -p tcp -j "$CHAIN_IN"
  iptables -C OUTPUT -p tcp -j "$CHAIN_OUT" 2>/dev/null || iptables -I OUTPUT 1 -p tcp -j "$CHAIN_OUT"
}

cmd_collect() {
  ensure_dependencies
  ensure_state_dir
  save_totals_snapshot
}

cmd_sync() {
  ensure_dependencies
  ensure_state_dir
  save_totals_snapshot || true
  ensure_chains

  iptables -F "$CHAIN_IN"
  iptables -F "$CHAIN_OUT"

  local user port
  while IFS=$'\t' read -r user port; do
    [[ -n "$user" && -n "$port" ]] || continue
    iptables -A "$CHAIN_IN" -p tcp --dport "$port" -m comment --comment "mtproto:${user}:in" -j RETURN
    iptables -A "$CHAIN_OUT" -p tcp --sport "$port" -m comment --comment "mtproto:${user}:out" -j RETURN
  done < <(list_users)

  : > "$LAST_FILE"
  cmd_collect
}

cmd_report_tsv() {
  local filter_user="${1:-}"
  local source_file="${2:-$TOTALS_FILE}"
  ensure_state_dir
  cmd_collect

  declare -A totals_in=()
  declare -A totals_out=()
  local user port

  while IFS=$'\t' read -r user in_bytes out_bytes; do
    [[ -n "$user" ]] || continue
    totals_in["$user"]="${in_bytes:-0}"
    totals_out["$user"]="${out_bytes:-0}"
  done < "$source_file"

  while IFS=$'\t' read -r user port; do
    [[ -n "$user" ]] || continue
    if [[ -n "$filter_user" && "$user" != "$filter_user" ]]; then
      continue
    fi
    local in_bytes="${totals_in[$user]:-0}"
    local out_bytes="${totals_out[$user]:-0}"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$user" \
      "$port" \
      "$in_bytes" \
      "$out_bytes" \
      "$(( in_bytes + out_bytes ))"
  done < <(list_users)
}

cmd_report_total_tsv() {
  local filter_user="${1:-}"
  cmd_report_tsv "$filter_user" "$TOTALS_FILE"
}

cmd_report_month_tsv() {
  local filter_user="${1:-}"
  cmd_report_tsv "$filter_user" "$MONTH_FILE"
}

cmd_report() {
  local filter_user="${1:-}"
  printf '%-16s %-6s %-12s %-12s %-12s\n' "USER" "PORT" "IN" "OUT" "TOTAL"
  while IFS=$'\t' read -r user port in_bytes out_bytes total_bytes; do
    printf '%-16s %-6s %-12s %-12s %-12s\n' \
      "$user" \
      "$port" \
      "$(human_bytes "$in_bytes")" \
      "$(human_bytes "$out_bytes")" \
      "$(human_bytes "$total_bytes")"
  done < <(cmd_report_total_tsv "$filter_user")
}

cmd_report_month() {
  local filter_user="${1:-}"
  printf '%-16s %-6s %-12s %-12s %-12s\n' "USER" "PORT" "IN" "OUT" "MONTH"
  while IFS=$'\t' read -r user port in_bytes out_bytes total_bytes; do
    printf '%-16s %-6s %-12s %-12s %-12s\n' \
      "$user" \
      "$port" \
      "$(human_bytes "$in_bytes")" \
      "$(human_bytes "$out_bytes")" \
      "$(human_bytes "$total_bytes")"
  done < <(cmd_report_month_tsv "$filter_user")
}

cmd_bootstrap_month() {
  ensure_state_dir
  cmd_collect

  cp "$TOTALS_FILE" "$MONTH_FILE"
  printf '%s\n' "$(date +%Y-%m)" > "$MONTH_MARKER_FILE"
}

cmd_forget() {
  local user_name="${1:-}"
  [[ -n "$user_name" ]] || {
    echo "Usage: mtproto-traffic forget <user_name>" >&2
    exit 1
  }

  ensure_state_dir

  awk -F '\t' -v user="$user_name" '$1 != user' "$TOTALS_FILE" > "${TOTALS_FILE}.tmp"
  mv "${TOTALS_FILE}.tmp" "$TOTALS_FILE"

  awk -F '\t' -v user="$user_name" '$1 != user' "$LAST_FILE" > "${LAST_FILE}.tmp"
  mv "${LAST_FILE}.tmp" "$LAST_FILE"

  awk -F '\t' -v user="$user_name" '$1 != user' "$MONTH_FILE" > "${MONTH_FILE}.tmp"
  mv "${MONTH_FILE}.tmp" "$MONTH_FILE"
}

main() {
  local command="${1:-}"
  case "$command" in
    sync)
      cmd_sync
      ;;
    collect)
      cmd_collect
      ;;
    report)
      shift || true
      cmd_report "${1:-}"
      ;;
    report-tsv)
      shift || true
      cmd_report_total_tsv "${1:-}"
      ;;
    report-month)
      shift || true
      cmd_report_month "${1:-}"
      ;;
    report-month-tsv)
      shift || true
      cmd_report_month_tsv "${1:-}"
      ;;
    bootstrap-month)
      cmd_bootstrap_month
      ;;
    forget)
      shift || true
      cmd_forget "${1:-}"
      ;;
    help|-h|--help|'')
      usage
      ;;
    *)
      echo "Unknown command: $command" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
