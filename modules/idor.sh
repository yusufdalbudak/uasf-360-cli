#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "idor" "ID enumeration probes (benign IDs)" "access" "safe" "GET" "1" "0"
uasf_run_module_idor() {
  local t="${1%/}"
  local id
  for id in 1 999 10001; do
    local p
    for p in "/api/items/${id}" "/api/users/${id}" "/resources/${id}"; do
      uasf_probe_http "idor" "GET" "$t${p}" '{}' ""
    done
  done
}
