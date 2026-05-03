#!/usr/bin/env bash
set -Eeuo pipefail

UASF_PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export UASF_PKG_ROOT

# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/core.sh"
uasf_init_config

# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/platform.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/log.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/theme.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/deps.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/profiles.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/safety.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/scope.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/rate_limit.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/http.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/detection.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/verdict.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/payloads.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/waf_evasion.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/evidence.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/run_probe.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/scenario.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/report.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/vt_adapter.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/juice_lab.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/selftest.sh"

_shglob_null=0
shopt -s nullglob || _shglob_null=$?
for _mod in "${UASF_PKG_ROOT}/modules"/*.sh; do
  [[ -f "$_mod" ]] || continue
  # shellcheck disable=SC1090
  source "$_mod"
done
[[ ${_shglob_null} -eq 0 ]] || true

# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/plan_estimate.sh"

# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/cli.sh"
# shellcheck disable=SC1091
source "${UASF_PKG_ROOT}/lib/interactive_run.sh"

uasf_main_router "$@"
