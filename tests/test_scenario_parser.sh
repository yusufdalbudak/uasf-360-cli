#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export UASF_PKG_ROOT="$ROOT"
# shellcheck disable=SC1091
source "$ROOT/lib/scenario.sh"

uasf_scenario_detect_version "$ROOT/tests/fixtures/sample_scenario.json" | grep -q v1 || exit 1
jq '.steps | length' "$ROOT/tests/fixtures/sample_scenario.json" | grep -qx 1 || exit 1
echo "[test_scenario_parser] ok"
