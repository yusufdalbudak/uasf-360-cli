#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "sqli" "SQL injection probes" "injection" "safe" "GET" "1" "0"
uasf_run_module_sqli() {
  local t="${1%/}"
  local fn
  for fn in sqli_basic.txt sqli_safe_evasion.txt; do
    [[ "$fn" == "sqli_safe_evasion.txt" ]] && [[ "${UASF_LAB_MODE:-0}" != "1" ]] && continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local enc
      while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        uasf_probe_http "sqli" "GET" "$t/?uasf_q=${enc}" '{}' ""
      done < <(uasf_waf_query_param_encodings "$line")
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/$fn")
  done
}
