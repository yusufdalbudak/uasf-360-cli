#!/usr/bin/env bash
# shellcheck shell=bash
# Sends safe GET probes with synthetic header surfaces and duplicated query keys
# (matches real WAAP anomaly tests; no CRLF, no protocol tampering).

uasf_register_module "waf_transport_evasion" "WAF/WAAP transport fingerprints (headers + HTTP pollution)" "waf" "safe" "GET" "0" "1"

uasf_run_module_waf_transport_evasion() {
  local t="${1%/}"

  [[ -f "$UASF_PAYLOAD_DIR/waf_sensitive_headers_hints.txt" ]] || return 0
  local line kk vv hdr
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    kk="${line%%|*}"
    vv="${line#*|}"
    kk="${kk//[[:space:]]/}"
    [[ -n "$kk" ]] || continue

    hdr=$(jq -nc --arg kk "$kk" --arg vv "$vv" \
      '{"X-UASF-TransportEcho":"hdr"} | . + {($kk): $vv}')
    uasf_probe_http "waf_transport_evasion" "GET" "${t%/}/" "$hdr" ""
  done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/waf_sensitive_headers_hints.txt")

  [[ -f "$UASF_PAYLOAD_DIR/waf_hpp_hints.txt" ]] || return 0
  local decoy enc
  decoy="$(uasf_urlencode "uasf_benign_placeholder")"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    while IFS= read -r enc; do
      [[ -z "$enc" ]] && continue
      uasf_probe_http "waf_transport_evasion" "GET" \
        "$t/?uasf_evade_q=${decoy}&uasf_evade_q=${enc}" '{}' ""
    done < <(uasf_waf_query_param_encodings "$line")
  done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/waf_hpp_hints.txt")
}
