#!/usr/bin/env bash
# shellcheck shell=bash
# Thin wrapper — requires external `vt` from https://github.com/HappyHackingSpace/vt
set -euo pipefail

VT_BIN="${UASF_VT_BIN:-vt}"

if [[ "$VT_BIN" != *[/]* ]] && ! command -v "$VT_BIN" >/dev/null 2>&1; then
  echo "vt not found. Install: go install github.com/happyhackingspace/vt/cmd/vt@latest" >&2
  echo "Or set UASF_VT_BIN to an executable path." >&2
  exit 127
fi
if [[ "$VT_BIN" == *[/]* ]] && [[ ! -x "$VT_BIN" ]]; then
  echo "UASF_VT_BIN is not executable: $VT_BIN" >&2
  exit 127
fi

exec "$VT_BIN" "$@"
