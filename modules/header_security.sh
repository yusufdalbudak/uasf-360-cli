#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "header_security" "Forwarded / host header spoof probes" "headers" "safe" "GET" "0" "0"
uasf_run_module_header_security() {
  local t="${1%/}"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local k="${line%%:*}"
    local v="${line#*:}"
    k="${k#"${k%%[![:space:]]*}"}"
    k="${k%"${k##*[![:space:]]}"}"
    v="${v#"${v%%[![:space:]]*}"}"
    [[ -z "$k" ]] && continue
    local hdr
    hdr=$(jq -nc --arg kk "$k" --arg vv "$v" '{($kk): $vv}')
    uasf_probe_http "header_security" "GET" "$t/" "$hdr" ""
  done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/header_probes.txt")
}
