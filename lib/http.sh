#!/usr/bin/env bash
# shellcheck shell=bash
# Canonical curl execution for UASF 360 CLI

UASF_LAST_HTTP_CODE=""
UASF_LAST_HTTP_MS=""
UASF_LAST_REMOTE_IP=""
UASF_LAST_SIZE_DOWNLOAD=""
UASF_LAST_HDR_FILE=""
UASF_LAST_BODY_FILE=""
UASF_LAST_BODY_WORKDIR=""
UASF_LAST_METHOD=""

# Args: METHOD URL HEADERS_JSON BODY
uasf_http_execute() {
  local method="$1"
  local url="$2"
  local headers_json
  if [[ $# -ge 3 ]]; then
    headers_json="$3"
    [[ -z "$headers_json" ]] && headers_json='{}'
  else
    headers_json='{}'
  fi
  local body="${4-}"

  UASF_LAST_METHOD="$method"
  UASF_LAST_HDR_FILE=""
  UASF_LAST_BODY_FILE=""
  if [[ -n "${UASF_LAST_BODY_WORKDIR:-}" ]]; then
    rm -rf "${UASF_LAST_BODY_WORKDIR}" 2>/dev/null || true
  fi

  local tdir
  tdir="$(uasf_mktemp_dir)"
  UASF_LAST_BODY_WORKDIR="$tdir"
  UASF_LAST_HDR_FILE="${tdir}/headers.raw"
  UASF_LAST_BODY_FILE="${tdir}/body.raw"

  uasf_scope_gate_request "$url"

  local corr="${UASF_CORRELATION_ID:-UASF-unknown}"
  local tl="${UASF_RUNTIME_TIMEOUT:?}"
  local maxdl="${UASF_MAX_DOWNLOAD_BYTES:-1048576}"
  local ct="${UASF_CONNECT_TIMEOUT:-10}"

  local curl_cmd=(-sS)
  if [[ "${UASF_HTTP_FOLLOW_REDIRECTS:-0}" == "1" ]]; then
    curl_cmd+=('-L')
  fi
  curl_cmd+=('-X' "$method" '--max-time' "$tl" '--connect-timeout' "$ct" '--max-filesize' "$maxdl")
  curl_cmd+=('-H' "X-UASF-Correlation: $corr")

  if [[ -n "$headers_json" ]] && [[ "$headers_json" != "{}" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      curl_cmd+=('-H' "$line")
    done < <(echo "$headers_json" | jq -r 'to_entries[] | "\(.key): \(.value)"')
  fi

  local datablob=""
  if [[ -n "$body" ]] && [[ "$body" != "null" ]]; then
    datablob="$(mktemp "${tdir}/post.XXXXXX")"
    printf '%s' "$body" >"$datablob"
    curl_cmd+=('--data-binary' "@${datablob}")
  fi

  local t0 ms
  t0=$(uasf_now_ms)
  local curl_out
  curl_out="$(
    LC_ALL=C curl "${curl_cmd[@]}" -o "${UASF_LAST_BODY_FILE}" -D "${UASF_LAST_HDR_FILE}" \
      -w '%{http_code}|%{remote_ip}|%{size_download}' "$url" 2>/dev/null || printf '%s' '000|-|0'
  )"

  ms=$(( $(uasf_now_ms) - t0 ))
  local _ifs="$IFS"
  IFS='|'
  curl_out="${curl_out//[$'\t\r\n']/}"
  read -r UASF_LAST_HTTP_CODE UASF_LAST_REMOTE_IP UASF_LAST_SIZE_DOWNLOAD <<<"$curl_out"
  IFS="$_ifs"
  [[ -z "${UASF_LAST_HTTP_CODE:-}" ]] && UASF_LAST_HTTP_CODE="000"
  [[ -n "${UASF_LAST_REMOTE_IP:-}" ]] || UASF_LAST_REMOTE_IP="-"
  [[ "${UASF_LAST_SIZE_DOWNLOAD:-0}" =~ ^[0-9]+$ ]] || UASF_LAST_SIZE_DOWNLOAD="0"
  UASF_LAST_HTTP_MS="$ms"
  rm -f "$datablob" 2>/dev/null || true
}

uasf_http_cleanup_bodydir() {
  if [[ -n "${UASF_LAST_BODY_WORKDIR:-}" ]]; then
    rm -rf "${UASF_LAST_BODY_WORKDIR}" 2>/dev/null || true
    UASF_LAST_BODY_WORKDIR=""
    UASF_LAST_HDR_FILE=""
    UASF_LAST_BODY_FILE=""
  fi
}
