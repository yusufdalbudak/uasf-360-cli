#!/usr/bin/env bash
# shellcheck shell=bash
# Scenario validation and execution (v1 legacy + v2)

uasf_scenario_detect_version() {
  local f="$1"
  local sch
  sch=$(jq -r '.schema // empty' "$f" 2>/dev/null)
  if [[ "$sch" == "uasf.scenario.v2" ]]; then
    echo "v2"
    return
  fi
  echo "v1"
}

uasf_validate_scenario_file() {
  local f="$1"
  local target_base="${2:-http://127.0.0.1}"
  local scope_rx="${3:-^http://127\.0\.0\.1}"

  [[ -f "$f" ]] || { uasf_log ERROR "not a file: $f"; return 1; }
  jq empty "$f" 2>/dev/null || { uasf_log ERROR "invalid JSON: $f"; return 1; }

  local ver
  ver=$(uasf_scenario_detect_version "$f")

  if [[ "$(jq 'has("name")' "$f")" != "true" ]] || [[ "$(jq 'has("steps")' "$f")" != "true" ]]; then
    uasf_log ERROR "missing name or steps in $f"
    return 1
  fi
  local n
  n=$(jq '.steps | length' "$f")
  [[ "$n" -gt 0 ]] || { uasf_log ERROR "scenario has zero steps"; return 1; }

  if [[ "$ver" == "v2" ]]; then
    local risk
    risk=$(jq -r '.risk // "safe"' "$f")
    if [[ "$risk" == "lab-only" ]] && [[ "${UASF_VALIDATE_LAB_OK:-1}" != "1" ]]; then
      uasf_log WARN "scenario marked lab-only: $f"
    fi
  fi

  local idx=0 maxrep="${UASF_SAFETY_MAX_STEP_REPEAT:-50}"
  while [[ "$idx" -lt "$n" ]]; do
    local meth path reps payref
    meth=$(jq -r ".steps[$idx].method // \"GET\"" "$f")
    path=$(jq -r ".steps[$idx].path // \"\"" "$f")
    reps=$(jq -r ".steps[$idx].repeat // 1 | tonumber" "$f")
    [[ "$reps" -le "$maxrep" ]] || { uasf_log ERROR "repeat $reps exceeds max $maxrep at step $idx"; return 1; }
    [[ -n "$path" ]] || { uasf_log ERROR "empty path step $idx"; return 1; }

    payref=""
    payref=$(jq -r ".steps[$idx].payload_ref // empty" "$f")
    if [[ -n "$payref" ]] && [[ ! -f "$UASF_PKG_ROOT/$payref" ]]; then
      uasf_log ERROR "payload_ref missing file: $payref"; return 1
    fi

    if [[ "$meth" =~ ^(POST|PUT|PATCH|DELETE)$ ]] && [[ "${UASF_VALIDATE_ALLOW_MUTATING:-0}" != "1" ]]; then
      uasf_log WARN "step $idx uses $meth — pass --allow-mutating-methods to validate-scenario to acknowledge"
    fi

    # URL scope check on composed URL
    local full="${target_base}${path}"
    if echo "$full" | grep -q '{{payload}}'; then
      full="${full//\{\{payload\}\}/probe}"
    fi
    uasf_validate_url_shape "$full" || { uasf_log ERROR "bad URL from step $idx"; return 1; }
    uasf_scope_match "$full" "$scope_rx" || { uasf_log ERROR "step $idx URL out of scope vs --scope-regex"; return 1; }

    idx=$((idx + 1))
  done

  uasf_log INFO "scenario OK: $f ($ver)"
  return 0
}

uasf_scenario_step_expect() {
  local f="$1"
  local idx="$2"
  local ver="$3"
  if [[ "$ver" == "v2" ]]; then
    jq -c ".steps[$idx].expect // {}" "$f"
    return
  fi
  local ec
  ec=$(jq -c ".steps[$idx].expect_http_codes // []" "$f")
  jq -nc --argjson ec "$ec" '{
    blocked_codes: ([403,406,429,451] + ($ec|map(select(. >= 400)))),
    allowed_codes: ([200,201,202,204] + ($ec|map(select(. < 400)))),
    challenge_patterns: ["captcha","access denied","blocked"]
  }'
}

uasf_run_scenario_file() {
  local f="$1"
  local target_base="${2:?}"
  local allow_mut="${3:-0}"

  local ver n
  ver=$(uasf_scenario_detect_version "$f")
  n=$(jq '.steps | length' "$f")
  local name
  name=$(jq -r '.name' "$f")

  uasf_log INFO "Running scenario: $name ($n steps)"
  uasf_run_echo ""
  uasf_run_echo "[scenario] ${name} (${n} steps)"

  local i=0
  while [[ "$i" -lt "$n" ]]; do
    local meth path headers body repeat sleep_ms expect_json pmod payref step_name
    meth=$(jq -r ".steps[$i].method // \"GET\"" "$f")
    path=$(jq -r ".steps[$i].path // \"/\"" "$f")
    headers=$(jq -c ".steps[$i].headers // {}" "$f")
    body=$(jq -r ".steps[$i].body // \"\"" "$f")
    repeat=$(jq -r ".steps[$i].repeat // 1" "$f")
    sleep_ms=$(jq -r ".steps[$i].sleep_ms // 0" "$f")
    step_name=$(jq -r ".steps[$i].name // \"step-$i\"" "$f")
    pmod=$(jq -r ".steps[$i].module // \"scenario\"" "$f")
    payref=$(jq -r ".steps[$i].payload_ref // empty" "$f")
    expect_json=$(uasf_scenario_step_expect "$f" "$i" "$ver")

    if [[ "$meth" =~ ^(POST|PUT|PATCH|DELETE)$ ]] && [[ "$allow_mut" != "1" ]]; then
      uasf_die "Scenario step $i requires mutating method $meth — re-run with --allow-mutating-methods"
    fi

    local lines_arr=()
    if [[ -n "$payref" ]]; then
      while IFS= read -r _ln; do lines_arr+=("$_ln"); done < <(uasf_payload_lines "$UASF_PKG_ROOT/$payref")
    fi
    if [[ ${#lines_arr[@]} -eq 0 ]]; then
      lines_arr+=("")
    fi

    local pline
    for pline in "${lines_arr[@]}"; do
      local r=0
      while [[ "$r" -lt "$repeat" ]]; do
        local enc_payload
        enc_payload=$(uasf_urlencode "$pline")
        local exec_path="$path"
        if [[ -n "$pline" ]]; then
          exec_path="$(uasf_expand_path_token "$path" "$enc_payload")"
        fi
        local url="${target_base}${exec_path}"
        if echo "$url" | grep -q '{{payload}}'; then
          uasf_die "Unresolved {{payload}} in scenario URL (missing payload_ref line?)"
        fi
        if ! uasf_validate_url_shape "$url"; then
          uasf_die "bad constructed url: $url"
        fi

        uasf_rate_limit_sleep_tick
        uasf_http_execute "$meth" "$url" "$headers" "$body"

        local hdr_for_ver="${UASF_LAST_HDR_FILE}"
        local bod_for_ver="${UASF_LAST_BODY_FILE}"

        local blocked_csv allowed_csv chpat
        blocked_csv=$(echo "$expect_json" | jq -r '(.blocked_codes // [403,406,429,451])|map(tostring)|join(",")')
        allowed_csv=$(echo "$expect_json" | jq -r '(.allowed_codes // [200,201,202,204])|map(tostring)|join(",")')
        chpat=$(echo "$expect_json" | jq -r '(.challenge_patterns // ["captcha","access denied","blocked"])|join("|")')

        local verdict
        verdict=$(uasf_verdict_for_response "${UASF_LAST_HTTP_CODE}" "$hdr_for_ver" "$bod_for_ver" \
          "$blocked_csv" "$allowed_csv" "$chpat" "${UASF_LAB_MODE:-0}")

        local fused hdrtxt
        hdrtxt="$(cat "$hdr_for_ver" 2>/dev/null)"
        fused="${hdrtxt}$(head -c 16384 "$bod_for_ver" 2>/dev/null || true)"
        local dw
        dw=$(uasf_detect_waf_bundle "$fused")
        local wfp wfc
        IFS='|' read -r wfp wfc <<<"$dw"

        uasf_evidence_finalize_response "${pmod}:${step_name}" "$meth" "$url" "$verdict" "$wfp" "$wfc"

        r=$((r + 1))
      done
    done

    if [[ "${sleep_ms:-0}" =~ ^[0-9]+$ ]] && [[ "$sleep_ms" -gt 0 ]]; then
      local ss
      ss=$(awk -v ms="$sleep_ms" 'BEGIN { printf "%f", ms/1000 }')
      sleep "$ss"
    fi
    i=$((i + 1))
  done
}
