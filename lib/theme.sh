#!/usr/bin/env bash
# shellcheck shell=bash
# CRT / terminal aesthetic for TTY stderr (respect NO_COLOR). Nothing third-party-named.

_uasf_theme_color_ok() {
  [[ "${NO_COLOR:-}" != "" ]] && return 1
  [[ -t 2 ]] || return 1
  return 0
}

# Optional FIGlet/wordmark — only when installed (keeps repos portable).
_uasf_theme_try_figlet_hello_friend() {
  command -v figlet >/dev/null 2>&1 || return 1
  local fb=""
  fb="$(figlet -f small -k "HELLO FRIEND" 2>/dev/null)" || return 1
  [[ -n "$(printf '%s' "$fb" | tr -d '[:space:]')" ]] || return 1
  {
    printf '\033[40m\033[1;91m'
    printf '%s' "$fb"
    printf '\033[0m\n'
  } >&2
  return 0
}

_uasf_theme_glitch_banner_plain() {
  cat <<'PL' >&2
+------------------------------------------------------------+
|                    H E L L O   ·   F R I E N D              |
|                 UASF 360 — control validation (Bash)       |
+------------------------------------------------------------+
PL
}

# Staggered chromatic-ish layers (simulate CRT bleed / mis-convergence).
_uasf_theme_glitch_banner_fancy() {
  printf '\033[40m' >&2
  printf '\033[2;32m%s\033[0m\n' >&2 "  █▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░░"
  printf '\033[40m\033[2;36m%s\033[0m\n' >&2 "      H E L L O                          F R I E N D"
  printf '\033[40m\033[1;91m%s\033[0m\n' >&2 "    H E L L O                            F R I E N D"
  printf '\033[40m\033[97;1m%s\033[0m\n' >&2 "   H E L L O                             F R I E N D"
  printf '\033[40m\033[2;32m%s\033[0m\n' >&2 "  █▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░▒▓░░"
  printf '\033[0m' >&2
}

uasf_theme_banner_interactive() {
  local ver=""
  [[ -f "${UASF_PKG_ROOT}/VERSION" ]] && ver="$(tr -d '\n' <"${UASF_PKG_ROOT}/VERSION")"

  printf '\n' >&2

  if _uasf_theme_color_ok; then
    _uasf_theme_try_figlet_hello_friend || _uasf_theme_glitch_banner_fancy
  else
    _uasf_theme_glitch_banner_plain
  fi

  printf '\n' >&2
  if _uasf_theme_color_ok; then
    printf '\033[40m\033[2;33m%s\033[0m\n' >&2 "  Authorized WAAP/WAF/API validation · written scope · defensive telemetry only."
    printf '\033[40m\033[91;2m%s\033[0m\n' >&2 " — — — correlation header: X-UASF-Correlation — — — "
  else
    printf '%s\n' "  Authorized WAAP/WAF/API validation · written scope · defensive telemetry only." >&2
    printf '%s\n' "  correlation header on every probe: X-UASF-Correlation" >&2
  fi

  [[ -z "$ver" ]] || printf '  framework version %s\n\n' "$ver" >&2
}

uasf_theme_strip_run_header() {
  [[ "${UASF_THEME_OFF:-0}" == "1" ]] && return 0
  local ver=""
  [[ -f "${UASF_PKG_ROOT}/VERSION" ]] && ver="$(tr -d '\n' <"${UASF_PKG_ROOT}/VERSION")"
  if _uasf_theme_color_ok; then
    printf '\033[40m\033[1;91m›\033[2;36m \033[1;91mUASF 360\033[0m' >&2
  else
    printf '%s' '› UASF 360' >&2
  fi
  [[ -z "$ver" ]] || printf ' %s' "$ver" >&2
  printf '\033[0m\n\n' >&2
}
