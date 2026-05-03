#!/usr/bin/env bash
# shellcheck shell=bash

uasf_detect_waf_bundle() {
  local text_sample="$1"
  local vendor="unknown"
  local conf="unknown"
  local best="$UASF_PKG_ROOT/config/waf-fingerprints.conf"

  if [[ ! -f "$best" ]]; then printf '%s|%s' "$vendor" "$conf"; return 0; fi

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    local vid cpat rx
    IFS='|' read -r vid cpat rx <<<"$line"
    [[ -n "$vid" ]] || continue
    [[ -n "$rx" ]] || continue
    if printf '%s' "$text_sample" | grep -Eiq "$rx"; then
      vendor="$vid"
      conf="$cpat"
      break
    fi
  done <"$best"

  printf '%s|%s' "$vendor" "$conf"
}
