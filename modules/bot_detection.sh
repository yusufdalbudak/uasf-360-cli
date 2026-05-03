#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "bot_detection" "Non-browser User-Agent probes" "bot" "safe" "GET" "1" "0"
uasf_run_module_bot_detection() {
  local t="${1%/}"
  while IFS= read -r ua; do
    [[ -z "$ua" ]] && continue
    local hdr
    hdr=$(jq -nc --arg u "$ua" '{"User-Agent": $u, "Accept": "*/*"}')
    uasf_probe_http "bot_detection" "GET" "$t/" "$hdr" ""
  done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/bot_agents.txt")
}
