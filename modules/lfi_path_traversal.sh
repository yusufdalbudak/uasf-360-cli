#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "lfi_path_traversal" "Path traversal / LFI probes" "injection" "safe" "GET" "1" "0"
uasf_run_module_lfi_path_traversal() {
  local t="${1%/}"
  local payload_files=(lfi_path_traversal.txt)
  if uasf_waf_evasion_lab_tier_enabled; then
    payload_files+=(lfi_evasion_lab.txt)
  fi
  local pn
  for pn in "${payload_files[@]}"; do
    [[ -f "$UASF_PAYLOAD_DIR/$pn" ]] || continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local enc
      while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        uasf_probe_http "lfi_path_traversal" "GET" "$t/?uasf_file=${enc}" '{}' ""
      done < <(uasf_waf_query_param_encodings "$line")
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/$pn")
  done
}
