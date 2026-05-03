#!/usr/bin/env bash
# shellcheck shell=bash

uasf_probe_http() {
  local mod="$1"
  local meth="$2"
  local url="$3"
  local hdr body
  if [[ $# -ge 4 ]]; then
    hdr="$4"
    [[ -z "$hdr" ]] && hdr='{}'
  else
    hdr='{}'
  fi
  body="${5-}"

  uasf_rate_limit_sleep_tick
  uasf_http_execute "$meth" "$url" "$hdr" "$body"
  UASF_LAST_RECORDED_HTTP_CODE="${UASF_LAST_HTTP_CODE:-0}"

  local hv="${UASF_LAST_HDR_FILE:-}"
  local bv="${UASF_LAST_BODY_FILE:-}"
  local fused=""
  fused="$(cat "$hv" 2>/dev/null)"
  fused="${fused}$(head -c 16384 "$bv" 2>/dev/null || true)"
  local dw
  dw=$(uasf_detect_waf_bundle "$fused")

  local verdict
  verdict=$(uasf_verdict_for_response "${UASF_LAST_HTTP_CODE:-0}" "$hv" "$bv" \
    '403,406,418,451,429' '200,201,202,204' 'captcha|access denied|blocked|web application firewall' "${UASF_LAB_MODE:-0}")

  local wfp wfc
  IFS='|' read -r wfp wfc <<<"$dw"
  uasf_evidence_finalize_response "$mod" "$meth" "$url" "$verdict" "$wfp" "$wfc"
}
