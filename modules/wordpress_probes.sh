#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "wordpress_probes" "WordPress path probes" "cms" "safe" "GET" "1" "0"
uasf_run_module_wordpress_probes() {
  local t="${1%/}"
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    local enc="${path#"${path%%[![:space:]]*}"}"
    [[ "$enc" == /* ]] || enc="/${enc}"
    enc="${enc// /%20}"
    uasf_probe_http "wordpress_probes" "GET" "${t%/}${enc}" '{}' ""
  done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/wordpress_signatures.txt")
}
