#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[test_cli] invoking help"
"$ROOT/uasf.sh" --help >/dev/null
echo "[test_cli] list-modules OK"
mods=$("$ROOT/uasf.sh" list-modules) || true
echo "$mods" | grep -Fq sqli || { echo FAIL; exit 1; }
pl_out=$("$ROOT/uasf.sh" plan run \
  --target http://127.0.0.1:3000 \
  --scope-regex '^http://127\.0\.0\.1(:[0-9]+)?(/|$|[?])' \
  --profile quick 2>/dev/null)
echo "$pl_out" | grep -Fq 'estimated HTTP total' || { echo FAIL plan run; exit 1; }
ps_out=$("$ROOT/uasf.sh" plan run \
  --target http://127.0.0.1 \
  --scope-regex '^http://127\.0\.0\.1' \
  --scenario "$ROOT/scenarios/api-smoke.json" 2>/dev/null)
echo "$ps_out" | grep -Fq 'estimated HTTP requests' || { echo FAIL plan scenario total; exit 1; }
echo "[test_cli] ok"
