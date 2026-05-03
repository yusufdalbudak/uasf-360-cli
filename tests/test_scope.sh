#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export UASF_PKG_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/lib/platform.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/log.sh"
# shellcheck disable=SC1091
source "$ROOT/lib/scope.sh"

UASF_RUNTIME_TARGET=""
UASF_SCOPE_REGEX='^https://example\.com'

uasf_validate_url_shape "https://example.com/foo" || exit 1
uasf_scope_match "https://example.com/foo" '^https://example\.com' || exit 1
uasf_scope_match "https://evil.com" '^https://example\.com' && exit 1
_rx="$(uasf_derive_scope_regex_from_url "http://127.0.0.1:3000/")"
[[ "$_rx" == '^http://127\.0\.0\.1(:[0-9]+)?(/|$|[?])' ]] || { echo "FAIL derive scope $_rx"; exit 1; }
echo "[test_scope] ok"
