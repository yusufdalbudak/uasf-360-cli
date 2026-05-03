#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "waf_fingerprint" "Homepage fingerprint (passive/active GET)" "waf" "safe" "GET" "1" "0"
uasf_run_module_waf_fingerprint() {
  local t="${1%/}"
  uasf_probe_http "waf_fingerprint" "GET" "$t/" '{}' ""
}
