#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "api_json" "JSON-oriented GET probes (query echoes)" "api" "safe" "GET" "1" "0"
uasf_run_module_api_json() {
  local t="${1%/}"
  local aj=(api_json.txt)
  if uasf_waf_evasion_lab_tier_enabled; then
    aj+=(api_json_lab_evasion.txt)
  fi
  local fn
  for fn in "${aj[@]}"; do
    [[ -f "$UASF_PAYLOAD_DIR/$fn" ]] || continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local enc
      while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        uasf_probe_http "api_json" "GET" "$t/?uasf_json=${enc}" '{}' ""
      done < <(uasf_waf_query_param_encodings "$line")
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/$fn")
  done
}
