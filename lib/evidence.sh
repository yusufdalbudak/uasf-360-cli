#!/usr/bin/env bash
# shellcheck shell=bash

uasf_redact_headers_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if command -v perl >/dev/null 2>&1; then
    perl -i -ne 'print unless /^Authorization:|^Cookie:|^Set-Cookie:|^X-Api-Key:|^Proxy-Authorization:/i' "$f"
  fi
}

uasf_body_sample() {
  local src="$1"
  local dst="$2"
  local max="${UASF_MAX_BODY_BYTES:-8192}"
  head -c "$max" "$src" >"$dst" 2>/dev/null || printf '' >"$dst"
}

uasf_run_init_artifacts() {
  local out="$1"
  mkdir -p "$out/evidence" || true
  UASF_RUN_ROOT="$out"
  UASF_RUN_NDJSON_PATH="${out}/results.ndjson"
  UASF_RUN_CSV_PATH="${out}/results.csv"
  UASF_RUN_AUDIT_PATH="${out}/audit.log"
  : >"$UASF_RUN_NDJSON_PATH"
  : >"$UASF_RUN_AUDIT_PATH"
  printf '"ts","correlation","module","method","url","http_code","ms","verdict","waf_vendor","waf_confidence"\n' >"$UASF_RUN_CSV_PATH"
  {
    printf 'audit_start utc=%s correlation=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${UASF_CORRELATION_ID:-}"
  } >>"$UASF_RUN_AUDIT_PATH"
}

uasf_evidence_finalize_response() {
  local module="$1"
  local method="$2"
  local url="$3"
  local verdict="$4"
  local wfp="$5"
  local wfc="$6"

  local run_ev="${UASF_RUN_ROOT:?}/evidence"
  mkdir -p "$run_ev"

  local slug
  slug="$(date +%Y%m%d_%H%M%S)_$$_${RANDOM}"
  if [[ -f "${UASF_LAST_HDR_FILE:-}" ]]; then
    cp "${UASF_LAST_HDR_FILE}" "${run_ev}/${slug}_resp_headers.txt" 2>/dev/null || true
    uasf_redact_headers_file "${run_ev}/${slug}_resp_headers.txt"
  fi

  local sample_meta="${run_ev}/${slug}_req_meta.json"
  jq -nc \
    --arg corr "${UASF_CORRELATION_ID}" \
    --arg mod "$module" \
    --arg method "$method" \
    --arg url "$url" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{schema:"uasf.request_meta.v1",correlation_id:$corr,module:$mod,method:$method,url:$url,ts:$ts}' >"$sample_meta"

  local body_sample="${run_ev}/${slug}_resp_body_sample.txt"
  if [[ -f "${UASF_LAST_BODY_FILE:-}" ]]; then
    uasf_body_sample "${UASF_LAST_BODY_FILE}" "$body_sample"
  else
    printf '' >"$body_sample"
  fi

  local code="${UASF_LAST_HTTP_CODE:-0}"
  local nd="$UASF_RUN_NDJSON_PATH"
  jq -nc \
    --arg corr "${UASF_CORRELATION_ID}" \
    --arg mod "$module" \
    --arg meth "$method" \
    --arg url "$url" \
    --arg code "${UASF_LAST_HTTP_CODE:-0}" \
    --arg ms "${UASF_LAST_HTTP_MS:-0}" \
    --arg rip "${UASF_LAST_REMOTE_IP:--}" \
    --arg sz "${UASF_LAST_SIZE_DOWNLOAD:-0}" \
    --arg ver "$verdict" \
    --arg wf "$wfp" \
    --arg wfcn "$wfc" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
       schema:"uasf.event.v1",
       correlation_id:$corr,module:$mod,method:$meth,target_url:$url,ts:$ts,
       http_code: ( $code | tonumber ),
       duration_ms: ( $ms | tonumber ),
       remote_ip:$rip,response_bytes: ( $sz | tonumber ),
       verdict:$ver,waf_vendor:$wf,waf_confidence:$wfcn
    }' >>"$nd"

  printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${UASF_CORRELATION_ID}" "$module" "$method" "$url" \
    "${code}" "${UASF_LAST_HTTP_MS:-0}" "$verdict" "$wfp" "$wfc" >>"${UASF_RUN_CSV_PATH}"

  {
    printf 'request utc=%s corr=%s mod=%s %s url=%s code=%s ms=%s verdict=%s waf=%s:%s slug=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${UASF_CORRELATION_ID}" "$module" "$method" "$url" \
      "$code" "${UASF_LAST_HTTP_MS:-0}" "$verdict" "$wfp" "$wfc" "$slug"
  } >>"${UASF_RUN_AUDIT_PATH}"

  if uasf_run_progress_enabled; then
    local _u
    _u="$(uasf_run_trunc_url "$url")"
    uasf_run_echo "  $(uasf_ts)  ${method}  ${_u}"
    uasf_run_echo "             http=${code}  ${UASF_LAST_HTTP_MS:-0}ms  verdict=${verdict}  waf=${wfp}:${wfc}"
  fi

  uasf_http_cleanup_bodydir
}
