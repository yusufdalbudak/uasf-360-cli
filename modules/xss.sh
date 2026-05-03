#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "xss" "XSS probes" "injection" "safe" "GET" "1" "0"
uasf_run_module_xss() {
  local t="${1%/}"
  local fn
  for fn in xss_basic.txt xss_dom_signatures.txt; do
    [[ -f "$UASF_PAYLOAD_DIR/$fn" ]] || continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local enc
      while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        uasf_probe_http "xss" "GET" "$t/?uasf_x=${enc}" '{}' ""
      done < <(uasf_waf_query_param_encodings "$line")
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/$fn")
  done
  if uasf_waf_evasion_lab_tier_enabled; then
    [[ -f "$UASF_PAYLOAD_DIR/xss_lab_evasion.txt" ]] || return 0
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local enc
      while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        uasf_probe_http "xss" "GET" "$t/?uasf_x=${enc}" '{}' ""
      done < <(uasf_waf_query_param_encodings "$line")
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/xss_lab_evasion.txt")
  fi
}
