#!/usr/bin/env bash
# shellcheck shell=bash
# Interactive wizard for ./uasf.sh run --interactive (requires a TTY on stdin)

uasf_interactive_derive_scope_regex_from_url() {
  uasf_derive_scope_regex_from_url "$@"
}

uasf_cmd_run_interactive() {
  [[ -t 0 ]] || uasf_die "Interactive mode needs a real terminal on stdin. Omit --interactive and pass --target / --scope-regex / --profile / --out explicitly."

  local target="" scope="" profile="" out="" scenario=""
  local rps_in="" to_in=""
  local mods="" lab_ok=0
  local hav_waf_ev=0
  local tail=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target) target="$2"; shift 2 ;;
      --scope-regex) scope="$2"; shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      --scenario) scenario="$2"; shift 2 ;;
      --rps) rps_in="$2"; shift 2 ;;
      --timeout) to_in="$2"; shift 2 ;;
      --modules) mods="$2"; shift 2 ;;
      --lab-mode) lab_ok=1; tail+=("$1"); shift ;;
      --waf-evasion)
        hav_waf_ev=1
        tail+=("$1" "$2")
        shift 2
        ;;
      --no-theme) UASF_THEME_OFF=1; shift ;;
      --i-understand | --allow-mutating-methods | --html | --quiet | --verbose)
        tail+=("$1"); shift ;;
      *)
        tail+=("$1"); shift ;;
    esac
  done

  uasf_theme_banner_interactive

  if [[ -z "$target" ]]; then
    printf '\n%s' '› Target URL (e.g. https://lab.example.com): ' >&2
    IFS= read -r target || true
  fi
  target="${target//[[:space:]]/}"
  if [[ -n "$target" ]] && [[ "$target" != *"://"* ]]; then
    target="https://${target}"
  fi
  [[ -n "$target" ]] || uasf_die "Target URL is required"
  uasf_validate_url_shape "$target" || uasf_die "Invalid URL shape: $target"
  target="${target%/}"

  local sugg=""
  sugg="$(uasf_interactive_derive_scope_regex_from_url "$target" || true)"
  if [[ -z "$scope" ]]; then
    if [[ -n "$sugg" ]]; then
      printf '%s' "› Scope regex [Enter = ${sugg}]: " >&2
    else
      printf '%s' '› Scope regex (cannot auto-detect for this URL shape): ' >&2
    fi
    IFS= read -r scope || true
    [[ -z "$scope" ]] && scope="$sugg"
  fi
  [[ -n "$scope" ]] || uasf_die "--scope-regex is required (could not derive one)"
  uasf_scope_match "$target" "$scope" || uasf_log WARN "Target URL may not match the scope regex; tighten --scope-regex if requests are rejected."

  if [[ -z "$profile" ]]; then
    printf '\n%s\n' '› Test profile (probe bundle):' >&2
    printf '%s\n' \
      '   1) quick      — fast surface checks' \
      '   2) demo       — broader GET lab bundle' \
      '   3) api        — API / JSON / GraphQL hooks' \
      '   4) full-safe  — full GET breadth' \
      '   5) full-lab   — POST + rate-limit (needs --lab-mode)' \
      '   6) custom     — comma-separated module ids (see ./uasf.sh list-modules)' >&2
    printf '%s' '› Choice [1-6, default 2]: ' >&2
    IFS= read -r pch || true
    pch="${pch:-2}"
    case "$pch" in
      1) profile=quick ;;
      2) profile=demo ;;
      3) profile=api ;;
      4) profile=full-safe ;;
      5) profile=full-lab ;;
      6)
        profile=custom
        if [[ -z "$mods" ]]; then
          printf '%s' '› Module ids (comma-separated): ' >&2
          IFS= read -r mods || true
        fi
        ;;
      *) uasf_die "Invalid profile choice: $pch" ;;
    esac
  fi

  if [[ "$profile" == "custom" ]] && [[ -z "${mods// /}" ]]; then
    printf '%s' '› Module ids (comma-separated): ' >&2
    IFS= read -r mods || true
  fi

  if [[ "$profile" == "custom" ]]; then
    [[ -n "${mods// /}" ]] || uasf_die "custom profile needs at least one module id"
  fi

  if [[ "$profile" == "full-lab" ]] && [[ "$lab_ok" != "1" ]]; then
    printf '%s' '› full-lab requires --lab-mode. Enable now? [y/N]: ' >&2
    IFS= read -r yl || true
    if [[ "$yl" =~ ^[yY](es)?$ ]]; then
      lab_ok=1
      tail+=(--lab-mode)
    else
      uasf_die "Choose another profile or answer y to enable lab mode."
    fi
  fi

  if [[ "$hav_waf_ev" != "1" ]]; then
    local _def
    if [[ "$lab_ok" == "1" ]]; then
      _def=standard
    else
      _def=off
    fi
    printf '%s' "› WAF evasion tier for injection payloads (off|standard|lab) [Enter=${_def}]: " >&2
    IFS= read -r _wev || true
    [[ -z "${_wev// /}" ]] && _wev="$_def"
    _wev=$(printf '%s' "$_wev" | LC_ALL=C tr '[:upper:]' '[:lower:]')
    case "$_wev" in off | standard | lab) ;;
      *) uasf_die "WAF evasion tier must be off, standard, or lab (got ${_wev})" ;;
    esac
    if [[ "$_wev" == lab ]] && [[ "$lab_ok" != "1" ]]; then
      uasf_log WARN "tier lab requires --lab-mode; using standard instead"
      _wev=standard
    fi
    tail+=(--waf-evasion "$_wev")
  fi

  if [[ -z "$out" ]]; then
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)-${RANDOM}"
    out="./output/uasf-interactive-${stamp}"
    printf '\n%s' "› Output directory [Enter = ${out}]: " >&2
    IFS= read -r oin || true
    [[ -n "${oin// /}" ]] && out="$oin"
  fi

  if [[ -z "${rps_in// /}" ]]; then
    printf '%s' "› Max requests/sec [Enter = ${UASF_DEFAULT_RPS:-2}]: " >&2
    IFS= read -r rps_in || true
  fi
  if [[ -z "${to_in// /}" ]]; then
    printf '%s' "› Per-request timeout seconds [Enter = ${UASF_DEFAULT_TIMEOUT:-10}]: " >&2
    IFS= read -r to_in || true
  fi

  local z
  for z in "${tail[@]}"; do
    [[ "$z" == --i-understand ]] && export UASF_I_UNDERSTAND=1
  done

  uasf_scope_classify_local "$target"
  if ! uasf_ack_satisfied; then
    printf '\n%s\n' '› Non-local target: confirm you have written authorization to test this host.' >&2
    printf '%s' '  Type YES (uppercase) to continue: ' >&2
    IFS= read -r yack || true
    [[ "$yack" == "YES" ]] || uasf_die "Aborted (acknowledgement required for non-local targets)."
    tail+=(--i-understand)
  fi

  local args=(
    --target "$target"
    --scope-regex "$scope"
    --profile "$profile"
    --out "$out"
  )
  [[ -n "$scenario" ]] && args+=(--scenario "$scenario")
  [[ -n "${rps_in// /}" ]] && args+=(--rps "$rps_in")
  [[ -n "${to_in// /}" ]] && args+=(--timeout "$to_in")
  [[ "$profile" == "custom" ]] && args+=(--modules "${mods// /}")
  args+=("${tail[@]}")

  printf '\n%s\n' 'Starting run with the choices above…' >&2
  uasf_cmd_run_parse "${args[@]}"
}
