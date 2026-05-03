#!/usr/bin/env bash
# shellcheck shell=bash
# OWASP Juice Shop — local Docker lab for ./uasf.sh run (isolated networks only).

uasf_juice_lab_dir() {
  printf '%s' "${UASF_PKG_ROOT}/labs/juice-shop"
}

uasf_juice_port_file() {
  printf '%s' "$(uasf_juice_lab_dir)/.uasf-juice.port"
}

uasf_juice_read_port() {
  local pf raw
  pf="$(uasf_juice_port_file)"
  if [[ -f "$pf" ]]; then
    raw=$(tr -cd '0-9' <"$pf" 2>/dev/null || true)
    [[ -n "$raw" ]] && printf '%s' "$raw" && return 0
  fi
  printf '%s' "${UASF_JUICE_PORT:-3000}"
}

uasf_juice_base_url() {
  local host="${UASF_JUICE_HOST:-127.0.0.1}"
  local p
  p="$(uasf_juice_read_port)"
  [[ "$p" =~ ^[0-9]+$ ]] || p="${UASF_JUICE_PORT:-3000}"
  printf 'http://%s:%s' "$host" "$p"
}

uasf_juice_compose() {
  local d old rc
  d="$(uasf_juice_lab_dir)"
  [[ -f "$d/docker-compose.yml" ]] || uasf_die "Missing $d/docker-compose.yml"
  old="$PWD"
  cd "$d" || uasf_die "cannot cd $d"
  rc=0
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@" || rc=$?
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@" || rc=$?
  else
    cd "$old" || true
    uasf_die "Docker Compose required (docker compose v2 plugin or docker-compose)"
  fi
  cd "$old" || true
  return "$rc"
}

uasf_juice_is_running() {
  uasf_cmd_present docker || return 1
  docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'uasf-juice-shop'
}

uasf_juice_print_help() {
  cat <<EOF
UASF — OWASP Juice Shop (Docker)

Starts the upstream Juice Shop image for local probes with ./uasf.sh run.
Use isolated lab VMs only — do not bind a public interface without intent.

Commands:
  juice start [--port N]    Start containers (writes .uasf-juice.port; default ${UASF_JUICE_PORT:-3000})
  juice stop                docker compose down; removes port file
  juice status              docker compose ps
  juice logs [--tail N]     Compose logs (default tail 80)
  juice wait [--timeout N]  Wait until Juice Shop responds (default ${UASF_JUICE_WAIT_TIMEOUT:-120}s)
  juice url                 Print base URL + derived --scope-regex + example ./uasf.sh run ...
  juice run ARGS...        If stack is down: start + wait; then ./uasf.sh run with --target/--scope-regex
                             (supply --profile, --out; add --lab-mode / --waf-evasion as needed)

Env (see config/default.conf): UASF_JUICE_HOST, UASF_JUICE_PORT, UASF_JUICE_WAIT_TIMEOUT,
  UASF_JUICE_IMAGE (maps to compose JUICE_SHOP_IMAGE), or JUICE_SHOP_* for one-off compose.

Files: $(uasf_juice_lab_dir)/docker-compose.yml
EOF
}

uasf_juice_start() {
  uasf_cmd_present docker || uasf_die "docker not found"
  local port="${UASF_JUICE_PORT:-3000}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --port)
        [[ $# -ge 2 ]] || uasf_die "juice start --port N"
        port="$2"
        shift 2
        ;;
      *) uasf_die "juice start: unknown option: $1" ;;
    esac
  done
  [[ "$port" =~ ^[0-9]+$ ]] || uasf_die "juice start: port must be numeric"
  export JUICE_SHOP_PORT="$port"
  [[ -n "${UASF_JUICE_IMAGE:-}" ]] && export JUICE_SHOP_IMAGE="$UASF_JUICE_IMAGE"
  uasf_juice_compose up -d --remove-orphans || uasf_die "docker compose up failed"
  printf '%s' "$port" >"$(uasf_juice_port_file)"
  uasf_log INFO "Juice Shop requested on port $port — run: ./uasf.sh juice wait"
}

uasf_juice_stop() {
  export JUICE_SHOP_PORT="$(uasf_juice_read_port)"
  [[ -n "${UASF_JUICE_IMAGE:-}" ]] && export JUICE_SHOP_IMAGE="$UASF_JUICE_IMAGE"
  uasf_juice_compose down --remove-orphans || true
  rm -f "$(uasf_juice_port_file)" 2>/dev/null || true
  uasf_log INFO "Juice Shop stack stopped."
}

uasf_juice_status() {
  export JUICE_SHOP_PORT="$(uasf_juice_read_port)"
  [[ -n "${UASF_JUICE_IMAGE:-}" ]] && export JUICE_SHOP_IMAGE="$UASF_JUICE_IMAGE"
  uasf_juice_compose ps
}

uasf_juice_logs() {
  local tail_lines=80
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tail)
        tail_lines="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  export JUICE_SHOP_PORT="$(uasf_juice_read_port)"
  [[ -n "${UASF_JUICE_IMAGE:-}" ]] && export JUICE_SHOP_IMAGE="$UASF_JUICE_IMAGE"
  uasf_juice_compose logs --tail "$tail_lines"
}

uasf_juice_wait_http() {
  local timeout_sec="${UASF_JUICE_WAIT_TIMEOUT:-120}"
  local base
  base="$(uasf_juice_base_url)"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout)
        [[ $# -ge 2 ]] || uasf_die "juice wait --timeout SEC"
        timeout_sec="$2"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  [[ "$timeout_sec" =~ ^[0-9]+$ ]] || uasf_die "timeout must be numeric"

  uasf_cmd_present curl || uasf_die "curl required for juice wait"

  local start_ts now_ts code
  start_ts=$(date +%s)
  uasf_log INFO "Waiting for Juice Shop at $base (timeout ${timeout_sec}s)…"
  while true; do
    code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 4 --max-time 8 "${base}/" 2>/dev/null || printf '000')
    if [[ "$code" =~ ^(200|302|301|304)$ ]]; then
      uasf_log INFO "Juice Shop is up ($base) http=$code"
      return 0
    fi
    now_ts=$(date +%s)
    if [[ $((now_ts - start_ts)) -ge "$timeout_sec" ]]; then
      uasf_die "Timed out waiting for ${base} — try: ./uasf.sh juice logs"
    fi
    sleep 2
  done
}

uasf_juice_print_url_hint() {
  local base rx
  base="$(uasf_juice_base_url)"
  rx="$(uasf_derive_scope_regex_from_url "$base")" || uasf_die "could not derive scope from $base"
  printf 'Base URL:     %s\n' "$base"
  printf 'Scope regex:  %s\n' "$rx"
  printf '\nExample:\n'
  printf "  ./uasf.sh run --target %s --scope-regex '%s' --profile demo --out ./output/juice-run --lab-mode\n" "$base" "$rx"
}
