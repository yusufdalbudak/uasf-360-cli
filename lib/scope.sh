#!/usr/bin/env bash
# shellcheck shell=bash
# URL validation and scope-regex enforcement

# Stable scope regex derived from URL for --scope-regex automation (HTTPS or HTTP hosts).
uasf_derive_scope_regex_from_url() {
  local url="$1"
  [[ "$url" =~ ^https?:// ]] || return 1
  local proto="${url%%:*}"
  local rest="${url#*://}"
  rest="${rest%%/*}"
  rest="${rest%%\?*}"
  local authstrip="${rest#*@}"
  local hp="$authstrip"
  local host=""
  if [[ "$hp" =~ ^\[([^]]+)\] ]]; then
    host="${BASH_REMATCH[1]}"
  else
    host="${hp%%:*}"
  fi
  [[ -n "$host" ]] || return 1
  local esc="${host//./\\.}"
  local pl
  pl=$(printf '%s' "$proto" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  case "$pl" in
    # Use [?] for a literal ? — avoid \? inside printf formats (can collapse to ? and break ERE).
    https) printf '^https://%s(:[0-9]+)?(/|$|[?])' "$esc" ;;
    http) printf '^http://%s(:[0-9]+)?(/|$|[?])' "$esc" ;;
    *) return 1 ;;
  esac
}

# Sets UASF_TARGET_IS_LOCAL=1 for loopback/private lab targets when URL matches conservative rules
uasf_scope_classify_local() {
  local url="$1"
  UASF_TARGET_IS_LOCAL=0
  if [[ "$url" =~ ^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?(/.*)?$ ]]; then UASF_TARGET_IS_LOCAL=1; return 0; fi
  if [[ "$url" =~ ^https?://(\[::1\])(:[0-9]+)?(/.*)?$ ]]; then UASF_TARGET_IS_LOCAL=1; return 0; fi
  if [[ "$url" =~ ^https?://10\.|^https?://192\.168\.|^https?://172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
    UASF_TARGET_IS_LOCAL=1
  fi
}

uasf_scope_forbidden_host() {
  local url="$1"
  local re="${UASF_FORBIDDEN_HOST_REGEX:-}"
  [[ -n "$re" ]] || return 1
  if echo "$url" | grep -Eiq "$re"; then
    return 0
  fi
  return 1
}

# Returns 0 if url matches scope extended regex
uasf_scope_match() {
  local url="$1"
  local rx="${2:-}"
  [[ -n "$rx" ]] || return 1
  echo "$url" | grep -Eq "$rx"
}

uasf_validate_url_shape() {
  local u="$1"
  [[ "$u" =~ ^https?:// ]] || return 1
  return 0
}

# Full gate: forbidden metadata hosts (non-lab), scope regex on full URL
uasf_scope_gate_request() {
  local url="$1"
  local scope_rx="${UASF_SCOPE_REGEX:-}"
  [[ -n "$scope_rx" ]] || uasf_die "Internal: scope regex missing"
  uasf_validate_url_shape "$url" || uasf_die "Invalid URL shape: $url"
  if uasf_scope_forbidden_host "$url"; then
    if [[ "${UASF_LAB_MODE:-0}" != "1" ]]; then
      uasf_die "URL host blocked by safety policy (use --lab-mode only with isolated lab targets): $url"
    fi
  fi
  uasf_scope_match "$url" "$scope_rx" || uasf_die "Scope violation — URL does not match --scope-regex: $url"
  return 0
}
