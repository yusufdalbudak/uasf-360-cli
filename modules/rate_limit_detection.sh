#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "rate_limit_detection" "Burst GET probes (lab-only)" "rate-limit" "lab-only" "GET" "0" "1"
uasf_run_module_rate_limit_detection() {
  local t="${1%/}"
  [[ "${UASF_LAB_MODE:-0}" == "1" ]] || return 0
  local max="${UASF_RATE_LIMIT_PROBE_MAX_REQUESTS_LAB:-25}"
  local i
  for ((i = 1; i <= max; i++)); do
    uasf_probe_http "rate_limit_detection" "GET" "$t/?uasf_rl_seq=${i}" '{}' ""
    if [[ "${UASF_LAST_RECORDED_HTTP_CODE:-}" == "429" ]]; then
      break
    fi
  done
}
