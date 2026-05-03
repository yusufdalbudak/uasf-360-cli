#!/usr/bin/env bash
# shellcheck shell=bash
# Approximate HTTP request counts for run — no network (operator dry-run / plan).

uasf_plan_lookup_module_lab_flag() {
  local mid="$1"
  local row
  for row in "${UASF_MODULE_ROWS[@]}"; do
    IFS='|' read -r iid _a _b _c _meth _sdef labf <<<"$row"
    if [[ "$iid" == "$mid" ]]; then
      printf '%s' "${labf:-0}"
      return 0
    fi
  done
  printf '0'
  return 0
}

uasf_plan_lab_module_skip() {
  local labf="$1"
  [[ "$labf" == "1" ]] && [[ "${UASF_LAB_MODE:-0}" != "1" ]]
}

# Upper-bound style multiplier vs uasf_waf_query_param_encodings (approximate).
uasf_plan_query_encoding_mult() {
  case "$(uasf_waf_evasion_level)" in
    lab) printf '4' ;;
    standard) printf '2' ;;
    *) printf '1' ;;
  esac
}

uasf_plan_cve_surface_mult() {
  case "$(uasf_waf_evasion_level)" in
    lab) printf '4' ;;
    standard) printf '2' ;;
    *) printf '1' ;;
  esac
}

uasf_plan_count_payload_lines() {
  local relpath="$1"
  local fp="${UASF_PAYLOAD_DIR}/${relpath}"
  [[ -f "$fp" ]] || { printf '0'; return 0; }
  uasf_payload_lines "$fp" | wc -l | tr -d ' \n'
}

uasf_plan_estimate_http_for_module() {
  local mid="${1:?}"
  local labf msg
  labf="$(uasf_plan_lookup_module_lab_flag "$mid")"
  if uasf_plan_lab_module_skip "$labf"; then
    printf '0|%s\n' "skipped (lab-only module; add --lab-mode to include)"
    return 0
  fi

  local em cves n hdr hpp rlmax
  em="$(uasf_plan_query_encoding_mult)"
  cves="$(uasf_plan_cve_surface_mult)"
  msg="approx"

  case "$mid" in
    sqli)
      local acc=0
      acc=$((acc + em * $(uasf_plan_count_payload_lines sqli_basic.txt)))
      if [[ "${UASF_LAB_MODE:-0}" == "1" ]]; then
        acc=$((acc + em * $(uasf_plan_count_payload_lines sqli_safe_evasion.txt)))
      fi
      printf '%s|%s\n' "$acc" "$msg"
      ;;
    xss)
      local xa=0
      xa=$((xa + em * $(uasf_plan_count_payload_lines xss_basic.txt)))
      xa=$((xa + em * $(uasf_plan_count_payload_lines xss_dom_signatures.txt)))
      if uasf_waf_evasion_lab_tier_enabled; then
        xa=$((xa + em * $(uasf_plan_count_payload_lines xss_lab_evasion.txt)))
      fi
      printf '%s|%s\n' "$xa" "$msg"
      ;;
    lfi_path_traversal)
      local xl=$((em * $(uasf_plan_count_payload_lines lfi_path_traversal.txt)))
      if uasf_waf_evasion_lab_tier_enabled; then
        xl=$((xl + em * $(uasf_plan_count_payload_lines lfi_evasion_lab.txt)))
      fi
      printf '%s|%s\n' "$xl" "$msg"
      ;;
    open_redirect)
      local xo=0
      xo=$((xo + em * $(uasf_plan_count_payload_lines open_redirect.txt)))
      if uasf_waf_evasion_lab_tier_enabled; then
        xo=$((xo + em * $(uasf_plan_count_payload_lines open_redirect_lab_evasion.txt)))
      fi
      printf '%s|%s\n' "$xo" "$msg"
      ;;
    api_json)
      local xa=$((em * $(uasf_plan_count_payload_lines api_json.txt)))
      if uasf_waf_evasion_lab_tier_enabled; then
        xa=$((xa + em * $(uasf_plan_count_payload_lines api_json_lab_evasion.txt)))
      fi
      printf '%s|%s\n' "$xa" "$msg"
      ;;
    cve_signature_probes)
      local lines=0
      lines=$((lines + $(uasf_plan_count_payload_lines cve_signature_probes.txt)))
      if [[ "${UASF_LAB_MODE:-0}" == "1" ]]; then
        lines=$((lines + $(uasf_plan_count_payload_lines cve_signature_probes_lab.txt)))
      fi
      n=$((lines * cves))
      printf '%s|%s\n' "$n" "$msg payloads×${cves}_surfaces"
      ;;
    waf_transport_evasion)
      hdr=$(uasf_plan_count_payload_lines waf_sensitive_headers_hints.txt)
      hpp=$((em * $(uasf_plan_count_payload_lines waf_hpp_hints.txt)))
      n=$((hdr + hpp))
      printf '%s|%s\n' "$n" "$msg headers+HPP×encodings"
      ;;
    rate_limit_detection)
      rlmax="${UASF_RATE_LIMIT_PROBE_MAX_REQUESTS_LAB:-25}"
      printf '%s|%s\n' "$rlmax" "worst-case burst cap (early exit often)"
      ;;
    bot_detection)
      n=$(uasf_plan_count_payload_lines bot_agents.txt)
      printf '%s|%s\n' "$n" "$msg"
      ;;
    header_security)
      n=$(uasf_plan_count_payload_lines header_probes.txt)
      printf '%s|%s\n' "$n" "$msg"
      ;;
    wordpress_probes)
      n=$(uasf_plan_count_payload_lines wordpress_signatures.txt)
      printf '%s|%s\n' "$n" "$msg"
      ;;
    api_graphql)
      n=$(uasf_plan_count_payload_lines api_graphql.txt)
      n=$((n * 2))
      printf '%s|%s\n' "$n" "$msg ×2 URLs/payload line"
      ;;
    idor) printf '%s|%s\n' "9" "3 ids × 3 paths" ;;
    auth_abuse) printf '%s|%s\n' "5" "fixed GET paths" ;;
    waf_fingerprint) printf '1|%s\n' "$msg" ;;
    *)
      printf '0|%s\n' "no estimate (unknown module id)"
      ;;
  esac
}

uasf_plan_scenario_total_http_est() {
  local f="$1"
  [[ -f "$f" ]] || {
    printf '0'
    return 0
  }
  local n i total repeat payref plc
  n=$(jq '.steps | length' "$f")
  total=0
  for ((i = 0; i < n; i++)); do
    repeat=$(jq -r ".steps[$i].repeat // 1 | tonumber" "$f")
    payref=$(jq -r ".steps[$i].payload_ref // empty" "$f")
    plc=1
    if [[ -n "$payref" ]] && [[ -f "${UASF_PKG_ROOT}/${payref}" ]]; then
      plc=$(uasf_payload_lines "${UASF_PKG_ROOT}/${payref}" | wc -l | tr -d ' \n')
      [[ "$plc" =~ ^[0-9]+$ ]] || plc=1
      [[ "${plc:-0}" -eq 0 ]] && plc=1
    fi
    total=$((total + repeat * plc))
  done
  printf '%s' "$total"
}

# Print plain-text plan to stdout. Exits via caller (cli) after printing.
uasf_emit_run_plan_report() {
  local target="$1"
  local scope="$2"
  local profile="$3"
  local scenario="$4"
  local out="$5"

  printf '\n━━━━━━━━ UASF run plan (no HTTP executed) ━━━━━━━━\n'
  printf 'target:    %s\n' "$target"
  printf 'scope-regex: %s\n' "$scope"
  printf 'profile:   %s\n' "$profile"
  printf 'waf-evade: %s\n' "$(uasf_waf_evasion_level)"
  printf 'lab-mode:  %s\n' "${UASF_LAB_MODE:-0}"
  printf 'rps:       %s\n' "${UASF_RUNTIME_RPS:-}"
  if [[ -n "$scenario" ]]; then
    printf 'scenario:  %s\n' "$scenario"
  else
    printf 'scenario: (none)\n'
  fi
  if [[ -n "$out" ]]; then
    printf 'out:       %s\n' "$out"
  else
    printf 'out:       (omit for plan/dry-run only)\n'
  fi

  local total=0 hdr n rp
  rp="${UASF_RUNTIME_RPS:-0}"
  if [[ -n "$scenario" ]]; then
    n="$(uasf_plan_scenario_total_http_est "$scenario")"
    total="$n"
    printf '\nestimated HTTP requests: %s (scenario steps × repeat × payload lines)\n' "$total"
    if [[ "$total" =~ ^[0-9]+$ ]] && [[ "$rp" =~ ^[0-9]+$ ]] && [[ "$rp" -gt 0 ]]; then
      local secs
      secs=$(((total + rp - 1) / rp))
      printf 'approx runtime floor: ~%ss at %s req/s RPS ceiling (exclusive of latency)\n' "$secs" "$rp"
    fi
    printf '\nNotes: Scenario counts ignore module runners; timings are indicative only.\n'
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    return 0
  fi

  local list="${UASF_PROFILE_MODULES_RAW// /}"
  IFS=',' read -ra MIDS <<<"$list"

  printf '\n%-26s %8s   %s\n' "module" "~http" "note"
  printf '%-26s %8s   %s\n' "-------------------------" "--------" "----"

  hdr=""
  for mid in "${MIDS[@]}"; do
    mid="${mid// /}"
    [[ -z "$mid" ]] && continue
    local line est note
    line="$(uasf_plan_estimate_http_for_module "$mid")"
    est="${line%%|*}"
    note="${line#*|}"
    if [[ "${est:-}" =~ ^[0-9]+$ ]]; then
      total=$((total + est))
    fi
    printf '%-26s %8s   %s\n' "$mid" "$est" "$note"
    if [[ "${est:-0}" -eq 0 ]] && [[ "$note" =~ skipped ]]; then
      hdr+="  - $mid: $note\n"
    fi
  done

  printf '\nestimated HTTP total: %s (~ bounds; encoding multipliers approximate)\n' "$total"
  rp="${UASF_RUNTIME_RPS:-0}"
  if [[ "$rp" =~ ^[0-9]+$ ]] && [[ "$rp" -gt 0 ]]; then
    local secs2
    secs2=$(((total + rp - 1) / rp))
    printf 'approx runtime floor: ~%ss at %s req/s RPS ceiling (exclusive of latency)\n' "$secs2" "$rp"
  fi
  if [[ -n "$hdr" ]]; then
    printf '\nskipped bundles:\n%s' "$hdr"
  fi
  printf '\nThis plan does not contact the target.\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}
