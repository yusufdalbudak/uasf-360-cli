#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export UASF_PKG_ROOT="$ROOT"
mkdir -p "$ROOT/tests/tmp_ev"
# shellcheck disable=SC1091
source "$ROOT/lib/verdict.sh"

HDR="$ROOT/tests/tmp_ev/h.txt"
BODY="$ROOT/tests/tmp_ev/b.txt"
echo "HTTP/1.1 403 Forbidden" >"$HDR"
echo "blocked by firewall" >"$BODY"
[[ "$(uasf_verdict_for_response 403 "$HDR" "$BODY" "403,406" "200" 'captcha')" == "BLOCKED" ]] || exit 1

echo "HTTP/1.1 429 Too Many" >"$HDR"
[[ "$(uasf_verdict_for_response 429 "$HDR" "$BODY")" == "RATE_LIMITED" ]] || exit 1
rm -rf "$ROOT/tests/tmp_ev"
echo "[test_verdict] ok"
