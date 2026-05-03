#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "open_redirect" "Open redirect probes" "redirect" "safe" "GET" "1" "0"
uasf_run_module_open_redirect() {
  local t="${1%/}"
  local ofs=(open_redirect.txt)
  if uasf_waf_evasion_lab_tier_enabled; then
    ofs+=(open_redirect_lab_evasion.txt)
  fi
  local of
  for of in "${ofs[@]}"; do
    [[ -f "$UASF_PAYLOAD_DIR/$of" ]] || continue
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local enc
      while IFS= read -r enc; do
        [[ -z "$enc" ]] && continue
        uasf_probe_http "open_redirect" "GET" "$t/?uasf_next=${enc}" '{}' ""
      done < <(uasf_waf_query_param_encodings "$line")
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/$of")
  done
}
