#!/usr/bin/env bash
# shellcheck shell=bash
# UASF 360 CLI — core globals and module registry

[[ -n "${UASF_PKG_ROOT:-}" ]] || {
  echo "UASF internal error: UASF_PKG_ROOT unset" >&2
  exit 2
}

export UASF_PKG_ROOT
UASF_CONFIG_DIR="${UASF_PKG_ROOT}/config"
UASF_LIB_DIR="${UASF_PKG_ROOT}/lib"
UASF_MOD_DIR="${UASF_PKG_ROOT}/modules"
UASF_PAYLOAD_DIR="${UASF_PKG_ROOT}/payloads"
UASF_SCENARIO_DIR="${UASF_PKG_ROOT}/scenarios"

# shellcheck disable=SC2034
UASF_MODULE_ROWS=()

uasf_register_module() {
  # id|display|category|risk|methods|safe_by_default|lab_only
  UASF_MODULE_ROWS+=("$1|$2|$3|$4|$5|$6|$7")
}

uasf_load_config_snippet() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "$f"
  set +a
}

uasf_init_config() {
  uasf_load_config_snippet "${UASF_CONFIG_DIR}/default.conf"
  uasf_load_config_snippet "${UASF_CONFIG_DIR}/safety.conf"
  if [[ -n "${UASF_USER_CONFIG:-}" ]] && [[ -f "$UASF_USER_CONFIG" ]]; then
    uasf_load_config_snippet "$UASF_USER_CONFIG"
  fi
}

uasf_mktemp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/uasf.XXXXXX"
}
