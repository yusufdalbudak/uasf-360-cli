#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Minimal lib stack for codec helpers only
export UASF_PKG_ROOT="$ROOT"
# shellcheck disable=SC1091
source "${ROOT}/lib/payloads.sh"
# shellcheck disable=SC1091
source "${ROOT}/lib/waf_evasion.sh"

unset UASF_WAF_EVASION || true

export UASF_WAF_EVASION=off
cnt_off=0
while IFS= read -r line; do
  [[ -n "$line" ]] && cnt_off=$((cnt_off + 1)) || true
done < <(uasf_waf_query_param_encodings "OR 1") || true

export UASF_WAF_EVASION=standard
cnt_std=0
while IFS= read -r line; do [[ -n "$line" ]] && cnt_std=$((cnt_std + 1)) || true; done \
  < <(uasf_waf_query_param_encodings "' OR '--") || true

export UASF_WAF_EVASION=lab
export UASF_LAB_MODE=1
cnt_lab=0
while IFS= read -r line; do [[ -n "$line" ]] && cnt_lab=$((cnt_lab + 1)) || true; done \
  < <(uasf_waf_query_param_encodings "1 UNION SELECT") || true

[[ "$cnt_off" -ge 1 ]] || { echo "FAIL expected >=1 variants at off"; exit 1; }
[[ "$cnt_std" -ge 2 ]] || { echo "FAIL expected >=2 variants at standard"; exit 1; }
[[ "$cnt_lab" -gt "$cnt_std" ]] || { echo "FAIL expected lab > standard variant count"; exit 1; }

echo "[test_waf_evasion] ok (off=${cnt_off} standard=${cnt_std} lab=${cnt_lab})"
