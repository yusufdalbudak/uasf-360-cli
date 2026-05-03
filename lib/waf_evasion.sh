#!/usr/bin/env bash
# shellcheck shell=bash
# WAF / WAAP validation-oriented encoding tiers (authorized targets only).

uasf_waf_evasion_level() {
  local lv
  lv="${UASF_WAF_EVASION:-off}"
  lv=$(printf '%s' "$lv" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  case "$lv" in off | standard | lab) ;; *) lv="off" ;; esac
  printf '%s\n' "$lv"
}

uasf_waf_evasion_standard_plus() {
  case "$(uasf_waf_evasion_level)" in standard | lab) return 0 ;; *) return 1 ;; esac
}

uasf_waf_evasion_lab_tier_enabled() {
  case "$(uasf_waf_evasion_level)" in lab) return 0 ;; *) return 1 ;; esac
}

# Emit URL-encoded forms of $1 suitable for concatenation after ?param=
# Lines are unique where possible (single-encode vs double-encode vs transforms).
uasf_waf_query_param_encodings() {
  local raw="$1"

  printf '%s\n' "$(uasf_urlencode "$raw")"

  uasf_waf_evasion_standard_plus || return 0
  printf '%s\n' "$(uasf_urlencode "$(uasf_urlencode "$raw")")"

  uasf_waf_evasion_lab_tier_enabled || return 0

  local tabs="${raw// /$'\t'}"
  if [[ "$tabs" != "$raw" ]]; then
    printf '%s\n' "$(uasf_urlencode "$tabs")"
  fi

  # SQL-ish token separators via block comments between spaces (engines that normalize /**/)
  local commented=""
  local need_comment=0
  case "$raw" in *[[:space:]]*) need_comment=1 ;; esac
  [[ "$need_comment" -eq 1 ]] || return 0
  case "$raw" in *OR*|*AND*|*UNION*|*SELECT*|*"'"*|*--*|*\;*)
    commented=$(LC_ALL=C printf '%s' "$raw" | sed 's/ /\/\*\*\//g')
    ;;
  *) return 0 ;;
  esac
  [[ "$commented" != "$raw" ]] || return 0
  printf '%s\n' "$(uasf_urlencode "$commented")"
}
