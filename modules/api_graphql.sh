#!/usr/bin/env bash
# shellcheck shell=bash
uasf_register_module "api_graphql" "GraphQL introspection-style GET probes" "api" "safe" "GET" "1" "0"
uasf_run_module_api_graphql() {
  local t="${1%/}"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local enc
    enc=$(uasf_urlencode "$line")
    uasf_probe_http "api_graphql" "GET" "$t/graphql?query=${enc}" '{}' ""
    uasf_probe_http "api_graphql" "GET" "$t/api/graphql?query=${enc}" '{}' ""
  done < <(uasf_payload_lines "$UASF_PAYLOAD_DIR/api_graphql.txt")
}
