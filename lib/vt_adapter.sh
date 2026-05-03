#!/usr/bin/env bash
# shellcheck shell=bash
# Adapter for Vulnerable Target (vt) — https://github.com/HappyHackingSpace/vt

# Override binary path (e.g. custom install): export UASF_VT_BIN=/opt/vt/vt
uasf_vt_bin_path() {
  printf '%s' "${UASF_VT_BIN:-vt}"
}

uasf_vt_available() {
  local b
  b="$(uasf_vt_bin_path)"
  if [[ "$b" == *[/]* ]] && [[ -x "$b" ]]; then
    return 0
  fi
  command -v "$b" >/dev/null 2>&1
}

uasf_vt_fail_msg() {
  cat >&2 <<'EOF'
vt (Vulnerable Target — Happy Hacking Space) is not installed or UASF_VT_BIN is not executable.

Project: https://github.com/HappyHackingSpace/vt
Templates: https://github.com/HappyHackingSpace/vt-templates

Install examples:
  go install github.com/happyhackingspace/vt/cmd/vt@latest
  # Optional: export UASF_VT_BIN=/path/to/vt

Needs Go 1.24+, Docker / Docker Compose. Use only isolated lab VMs/sandboxes.
See labs/vt/README.md for pairing vt with ./uasf.sh run ...
EOF
}

uasf_vt_do() {
  if ! uasf_vt_available; then
    uasf_vt_fail_msg
    return 127
  fi
  "$(uasf_vt_bin_path)" "$@"
}

uasf_vt_list_templates() {
  uasf_vt_do template --list
}

# Convenience for scripts calling start/stop explicitly.
uasf_vt_start() {
  uasf_vt_do start "$@"
}

uasf_vt_stop() {
  uasf_vt_do stop "$@"
}
