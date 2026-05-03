#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "auth_abuse" "Auth endpoint probes (GET)" "auth" "safe" "GET" "1" "0"
uasf_run_module_auth_abuse() {
  local t="${1%/}"
  local p
  for p in /login /signin /auth /oauth/authorize /.well-known/openid-configuration; do
    uasf_probe_http "auth_abuse" "GET" "$t${p}?uasf_auth_probe=1" '{}' ""
  done
}
