#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN="$ROOT/tests/tmp_run"
mkdir -p "$RUN"
export UASF_PKG_ROOT="$ROOT"
export UASF_CORRELATION_ID="test-corr"
export UASF_RUNTIME_VERBOSE=0

# shellcheck disable=SC1091
source "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/evidence.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/http.sh"

UASF_RUNTIME_ROOT="$RUN"
echo "HTTP/1.1 200 OK" >"$RUN/h.hdr"
echo "hello" >"$RUN/b.bin"
export UASF_LAST_HDR_FILE="$RUN/h.hdr"
export UASF_LAST_BODY_FILE="$RUN/b.bin"
export UASF_LAST_HTTP_CODE="200"
export UASF_LAST_HTTP_MS="42"
export UASF_LAST_REMOTE_IP="127.0.0.1"
export UASF_LAST_SIZE_DOWNLOAD="5"

export UASF_RUN_ROOT="$RUN"

uasf_run_init_artifacts "$RUN"
uasf_evidence_finalize_response "testmod" "GET" "https://example.com/" "ALLOWED" "unknown" "unknown"
[[ -f "$RUN/results.ndjson" ]] || exit 1
grep -q testmod "$RUN/results.csv" || exit 1

rm -rf "$RUN"

echo "[test_evidence] ok"
