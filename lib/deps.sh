#!/usr/bin/env bash
# shellcheck shell=bash
# Dependency checks for doctor command

uasf_cmd_present() {
  command -v "$1" >/dev/null 2>&1
}

uasf_doctor_json_version() {
  if uasf_cmd_present jq; then
    jq --version 2>&1 | head -1
  else
    echo "missing"
  fi
}

uasf_doctor() {
  echo "UASF 360 CLI — doctor"
  echo "======================"
  echo "OS: $(uname -s) $(uname -r)"
  echo "Shell: $SHELL"
  echo "Bash: ${BASH_VERSION:-unknown}"
  local wd
  wd="$(pwd)"
  echo "Working directory: $wd"
  if [[ -w "$wd" ]]; then echo "Write test (cwd): ok"; else echo "Write test (cwd): FAILED"; fi
  echo ""
  echo "Required:"
  echo "  bash: ok (running)"
  if uasf_cmd_present curl; then echo "  curl: $(curl --version | head -1)"; else echo "  curl: MISSING"; fi
  if uasf_cmd_present jq; then echo "  jq: $(uasf_doctor_json_version)"; else echo "  jq: MISSING (required)"; fi
  echo ""
  echo "Optional:"
  if uasf_cmd_present shellcheck; then echo "  shellcheck: $(shellcheck --version | head -1)"; else echo "  shellcheck: not installed"; fi
  if uasf_cmd_present docker; then echo "  docker: $(docker --version 2>/dev/null)"; else echo "  docker: not installed"; fi
  if uasf_cmd_present perl; then echo "  perl: timing precision helper available"; else echo "  perl: not installed (ms timing falls back)"; fi
  if declare -F uasf_vt_available >/dev/null 2>&1 && uasf_vt_available; then
    local vb
    vb="$(uasf_vt_bin_path)"
    echo "  vt: $($vb --help 2>&1 | head -1 || echo present) [$vb]"
  else
    echo "  vt: not installed (optional; HappyHackingSpace/vt — see labs/vt/README.md)"
  fi
  echo "  juice (OWASP): labs/juice-shop + ./uasf.sh juice help"
  echo ""
  echo "Paths:"
  echo "  UASF_PKG_ROOT: ${UASF_PKG_ROOT:-unset}"
}
