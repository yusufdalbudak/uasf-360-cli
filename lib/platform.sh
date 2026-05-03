#!/usr/bin/env bash
# shellcheck shell=bash
# Portable helpers (Linux + macOS, bash 3.2+)

# Milliseconds since epoch (best effort)
uasf_now_ms() {
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%.0f", time * 1000'
  else
    echo "$(date +%s)000"
  fi
}

uasf_hostname() {
  hostname 2>/dev/null || echo "unknown"
}

# realpath/dirname portability
uasf_realpath_safe() {
  local p="${1:?}"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || echo "$p"
  else
    # shellcheck disable=SC2164
    (cd "$(dirname "$p")" && echo "$(pwd -P)/$(basename "$p")") 2>/dev/null || echo "$p"
  fi
}
