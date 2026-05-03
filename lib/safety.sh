#!/usr/bin/env bash
# shellcheck shell=bash
# Pre-flight safety gates (paired with scope.sh before HTTP)

# Returns 0 when run is allowed without extra acknowledgement.
uasf_ack_satisfied() {
  [[ "${UASF_REQUIRE_ACK_NONLOCAL:-0}" != "1" ]] && return 0
  [[ "${UASF_TARGET_IS_LOCAL:-0}" == "1" ]] && return 0
  [[ "${UASF_I_UNDERSTAND:-0}" == "1" ]] && return 0
  [[ "${UASF_ACK:-}" == "1" ]] && return 0
  return 1
}

uasf_die_if_no_ack_nonlocal() {
  if uasf_ack_satisfied; then return 0; fi
  uasf_die "Refusing run: non-localhost target requires acknowledgement. Use flag --i-understand or export UASF_ACK=1 after obtaining written authorization."
}

# Reject writable output roots that are dangerously broad
uasf_validate_out_dir() {
  local out="$1"
  [[ -n "$out" ]] || uasf_die "--out path is empty"
  case "$out" in
    / | /etc/* | "$HOME" | "$HOME/"*) uasf_die "--out rejects path: $out (use a dedicated project subdirectory under ./output/)" ;;
  esac
  case "$out" in
    /tmp | /tmp/ | /var/tmp | /var/tmp/) uasf_die "--out must not be raw /tmp or /var/tmp root" ;;
  esac
  if [[ "${#out}" -lt 4 ]]; then
    uasf_die "--out path too short / ambiguous"
  fi
}
