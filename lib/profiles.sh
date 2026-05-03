#!/usr/bin/env bash
# shellcheck shell=bash

uasf_profile_section_line() {
  local name="$1"
  local key="$2"
  awk -v p="$name" -v k="$key" '
    BEGIN {insec=0}
    $0 ~ "^\\[profile:" p "\\]" { insec=1; next }
    /^\[/ { if (insec) exit }
    insec && $0 ~ "^" k "=" { sub(/^[^=]*=/,""); print; exit }
  ' "${UASF_PKG_ROOT}/config/profiles.conf"
}

uasf_profile_resolve() {
  local pname="$1"
  UASF_PROFILE_MODULES_RAW="$(uasf_profile_section_line "$pname" "modules" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
  UASF_PROFILE_METHODS="$(uasf_profile_section_line "$pname" "methods" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
  UASF_PROFILE_LAB_ONLY="$(uasf_profile_section_line "$pname" "lab_only" | tr -d '\r' | sed 's/^ *//;s/ *$//')"
}

uasf_methods_allow() {
  local need="$1"
  local csv="${UASF_RUNTIME_METHOD_POLICY:-GET}"
  local x
  IFS=',' read -ra xs <<<"${csv// /}"
  for x in "${xs[@]:-GET}"; do
    [[ "$x" == "$need" ]] && return 0
  done
  return 1
}
