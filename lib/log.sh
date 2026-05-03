#!/usr/bin/env bash
# shellcheck shell=bash

UASF_LOG_LEVEL="${UASF_LOG_LEVEL:-info}"

_uasf_level_ok() {
  case "$UASF_LOG_LEVEL" in
    quiet) return 1 ;;
    error) [[ "$1" == "ERROR" ]] ;;
    warn) [[ "$1" =~ ^(ERROR|WARN)$ ]] ;;
    *) return 0 ;;
  esac
}

uasf_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

uasf_log() {
  local lvl="$1"
  shift
  _uasf_level_ok "$lvl" || return 0
  printf '[%s] [%s] %s\n' "$(uasf_ts)" "$lvl" "$*" >&2
}

uasf_die() {
  uasf_log ERROR "$*"
  exit 1
}

# Live run progress on stderr (--quiet disables). Default matches interactive expectations.
uasf_run_progress_enabled() {
  [[ "${UASF_RUNTIME_VERBOSE:-1}" == "1" ]]
}

uasf_run_echo() {
  uasf_run_progress_enabled || return 0
  printf '%s\n' "$*" >&2
}

# Truncate long URLs for terminal progress lines (does not alter evidence URLs).
uasf_run_trunc_url() {
  local s="$1" n="${2:-118}"
  local m=$((n > 2 ? n - 1 : 1))
  if [[ ${#s} -le $n ]]; then
    printf '%s' "$s"
  else
    printf '%s…' "${s:0:$m}"
  fi
}
