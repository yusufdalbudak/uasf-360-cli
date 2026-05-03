#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "cve_signature_probes" "CVE-class WAF signatures (opaque, non-operative)" "injection" "safe" "GET" "1" "0"

# Fan the same opaque signature across delivery channels (authorized WAAP tuning).
# Query uasf_sig is the default; standard+ adds a generic param; lab adds header + Cookie.
uasf_cve_signature_probe_surfaces() {
  local t="${1%/}"
  local line="$2"
  local enc="$3"
  local base="${t%/}/"

  uasf_probe_http "cve_signature_probes" "GET" "$t/?uasf_sig=${enc}" '{}' ""

  uasf_waf_evasion_standard_plus || return 0
  uasf_probe_http "cve_signature_probes" "GET" "$t/?q=${enc}" '{}' ""

  uasf_waf_evasion_lab_tier_enabled || return 0
  local hdr ck
  hdr=$(jq -nc --arg v "$line" '{"X-UASF-Sig-Echo": $v}')
  uasf_probe_http "cve_signature_probes" "GET" "$base" "$hdr" ""
  ck=$(jq -nc --arg v "$enc" '{"Cookie": ("UASF_SIG_COOKIE=" + $v)}')
  uasf_probe_http "cve_signature_probes" "GET" "$base" "$ck" ""
}

uasf_run_module_cve_signature_probes() {
  local t="${1%/}"
  local fn enc line
  for fn in cve_signature_probes.txt cve_signature_probes_lab.txt; do
    [[ -f "$UASF_PAYLOAD_DIR/$fn" ]] || continue
    if [[ "$fn" == *_lab.txt ]] && [[ "${UASF_LAB_MODE:-0}" != "1" ]]; then
      continue
    fi
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      enc=$(uasf_urlencode "$line")
      uasf_cve_signature_probe_surfaces "$t" "$line" "$enc"
    done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/$fn")
  done
}
