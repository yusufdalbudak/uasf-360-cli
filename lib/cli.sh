#!/usr/bin/env bash
# shellcheck shell=bash
# CLI router for UASF 360 CLI — keep heavy logic minimal; libs do the work

uasf_help_run_document() {
  cat <<'RSOF'

COMMAND run — HTTP probe campaigns
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SYNOPSIS

  ./uasf.sh plan run [--target …] [same OPTIONS as **run**]   Estimate only; optional --out; no probes .

  ./uasf.sh run [--target …] **--dry-run** [OPTIONS …]         Same semantics as **plan run** .

  ./uasf.sh run --target URL --scope-regex REGEX --profile PROFILE --out DIR [OPTIONS …]
  ./uasf.sh run --target URL --scope-regex REGEX --scenario FILE --out DIR [OPTIONS …]

  • With --scenario, --profile defaults to scenario (explicit --profile not required).

  ./uasf.sh run [-i|--interactive] [OTHER OPTIONS …]
      Interactive wizard — must be used from a real TTY (stdin). Collects missing --target /
      --scope-regex / bundles / dirs / throughput / optional lab knobs.

SHORTCUT

  ./uasf.sh run --help       (or -h) — print ONLY this SECTION (easier scrolling).

REQUIRED FOR NON-INTERACTIVE run

  --target URL               Base HTTP(S) seed — trailing slash trimmed from host side.

  --scope-regex REGEX        Extended-regex gate (grep -Eq) enforced on EVERY generated probe URL .

  --out DIR                  Writable artifact directory (omit for **plan run** / **--dry-run**) .

PROBE BUNDLE MODES — pick ONE family

  (A) canned profile via config/profiles.conf

      --profile NAME         quick • demo • api • full-safe • full-lab • scenario • custom .

      NAME=custom ALSO needs:

      --modules id1,id2,…    Comma list — NO SPACES — use ./uasf.sh list-modules for ids .

  (B) JSON scenario driver

      --scenario PATH        Scenario JSON inside scenarios/*.json tree .
                             Methods / steps depend on scenario + --allow-mutating-methods interplay .

COMMON OPTIONS

  --dry-run                  Resolve bundles and print approximate HTTP totals (**no probes**, **no dirs**) .

  --rps N                    Soft rate ceiling (requests/sec tuning). Bounds in safety.conf .

  --timeout SEC               Per-transfer curl deadline (seconds). Caps at UASF_SAFETY_MAX_TIMEOUT .

  --lab-mode                  Unlocks modules marked lab_only and lab payload corpora .

  --i-understand              Explicit operator acknowledgment for WAN / non-loopback probing .
                              Alternatives include safety env knobs (see README / safety.conf).

  --allow-mutating-methods    Permit non-GET scenario verbs once scenario validation passes .

  --html                     Emit supplementary report.html beside CSV excerpts .

STDOUT / STDERR FOOTPRINT

  --quiet                     Collapse chatter — still emits completion line referencing OUT dir .

  --verbose                   Default rich stream (banner + probe lines + digest). This is baseline .

COSMETICS

  --no-theme                  Skip retro terminal banner motifs .

ADVANCED SCANNING

  --waf-evasion LEVEL         off • standard • lab .

                              standard → extra URL-encoding / dual-encoding layers .

                              lab      → ALSO tab + SQL comment-ish transforms AND broader CVE transports .
                              Requires --lab-mode for lab tier (auto-downgrades with warning otherwise).

RUNTIME ARTIFACT HIGHLIGHTS (under OUT)

  • summary.md           Human verdict rollups .

  • results.ndjson / results.csv machine streams .

  • audit.log           Greppable chronological operations trace .

  • run.json             Metadata fingerprint (framework version • correlation stem • scope echoes).

  • evidence/            Redacted excerpt folders per slugged transaction .

TECHNICAL NOTES

  • Mandatory header X-UASF-Correlation for SIEM slicing .

  • Non-interactive run rewires stdin FROM /dev/null (prevents phantom blocking on dashboards) .

RSOF
}

uasf_print_help() {
  cat <<'EOF'
UASF 360 CLI — Universal Application Security Validation Framework
Authorized WAAP / WAF / API validation (POSIX Bash toolchain). Ships without dashboards / SaaS tethering.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
META / GLOBAL FLAGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ./uasf.sh [--help|-h|help]
      Displays this reference. Running ./uasf.sh with ZERO extra arguments prints the same mural .

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PRIMARY COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  doctor
      Local capability inventory (bash runtime, curl TLS build, jq, optional docker / shellcheck /
      perl timer helpers / upstream vt shim). Executes quick scope-pattern smoke afterwards .

  init
      Creates ./output and ./evidence directories inside UASF_PKG_ROOT for ad-hoc runs .

  list-modules
      Tab-separated registry including lab_only sentinel + HTTP verbs each module asserts .

  list-scenarios
      Enumerates JSON scenario definitions with jq structural preflight .

  validate-scenario
      ARGS:
        --file PATH              REQUIRED scenario JSON artifact .
        --target URL             Default http://127.0.0.1 sandbox placeholder .
        --scope-regex RX         Default legacy loopback-ish regex starter — tighten consciously .
        --allow-mutating-methods Allows PUT/PATCH/DELETE declarations during validation .

  explain-scope
      ARGS:
        --target URL               REQUIRED —
        --scope-regex RX           REQUIRED — **grep -Eq** semantics on full URL strings .
        [--sample REL …]           Optional repeatable probe path (**/**path), or **?query=fragment** .

      Helps debug strict **REGEX** cages before committing to a WAN run .

  plan run …
       Same switches as **run**; emits module/scenario estimates then exits (--out optional) .

  report
      ARGS:
        --run DIR               REQUIRED pointing at prior OUTPUT directory containing NDJSON / CSV remnants .

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
REFERENCE — PROFILE BUNDLES  (mirror of config/profiles.conf)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  quick         GET probes: sqli, xss, open_redirect, header_security, waf_fingerprint .

  demo          Adds lfi_path_traversal, bot_detection, api_json, cve_signature_probes (GET only) .

  api           Focused JSON/API surface (+ idor • cve • fingerprint headers GET) .

  full-safe     Broad GET parity across core abuse classes + wordpress probes + CVE signatures .

  full-lab      GET+POST (rate_limit_detection, waf_transport_evasion…) — REQUIRES --lab-mode .

  scenario      Skeleton profile — marry with explicit --scenario JSON path .

  custom        Compose your own comma list via --modules (see list-modules registry) .

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUPPLEMENTARY run REFERENCE — scroll OR use ./uasf.sh run --help
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
  uasf_help_run_document

  cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DOCKER / vt INTEGRATIONS (offline lab scaffolding)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  vt adapter
      Proxies upstream Vulnerable Target tool (HappyHackingSpace / MIT).
      Repo: https://github.com/HappyHackingSpace/vt
      Templates index: https://github.com/HappyHackingSpace/vt-templates
      Invocation patterns:
          ./uasf.sh vt              # vt template --list shorthand
          ./uasf.sh vt list ARGS    # forwarded to vt template --list ARGS …
          ./uasf.sh vt start|stop … # passthrough verbatim
          ./uasf.sh vt ARGS …       # any other vt ARGS pass untouched ( vt ps • vt template --update ).
      Override binary discovery with env UASF_VT_BIN .

  juice helper
      Native compose stack under labs/juice-shop/ (image bkimminich/juice-shop).
          ./uasf.sh juice help
      Flow: juice start [--port N] • juice wait • juice run [--profile demo --out …]
      Overrides: UASF_JUICE_* env keys ( HOST • PORT • WAIT_TIMEOUT • IMAGE ) — see labs/juice-shop/README.md .

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NOTABLE ENV VARS — consult config/default.conf + safety.conf
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  UASF_USER_CONFIG            Optional AFTER-default shell snippet layering .

  UASF_CORRELATION_PREFIX     Prefix stitched into outbound X-UASF-Correlation id .

  Rate / body / download caps  UASF_DEFAULT_RPS • UASF_DEFAULT_TIMEOUT • UASF_MAX_BODY_BYTES •
                               UASF_MAX_DOWNLOAD_BYTES • UASF_CONNECT_TIMEOUT

  Networking nuance           UASF_HTTP_FOLLOW_REDIRECTS (scope hygiene)

  Probe aggressiveness defaults UASF_WAF_EVASION ( CLI --waf-evasion wins at runtime )

  Safety ceilings             UASF_SAFETY_MAX_RPS • UASF_SAFETY_MAX_TIMEOUT •
                               metadata-host ban via UASF_FORBIDDEN_HOST_REGEX

  LAB bridges                 UASF_VT_BIN • UASF_JUICE_HOST • UASF_JUICE_PORT • …

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
AUTHORIZATION & LIMITATION REMINDERS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  • Operators must possess written scope for every DESTINATION host / ENVIRONMENT .
  • Non-local probing requires explicit acknowledgement path consistent with YOUR org policy .

  • --scope-regex is deliberate containment — widen carefully .

  • lab-mode unlocks payloads that look offensive—ONLY on isolated rigs .

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FAST START (local OWASP Juice Shop + demo profile)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ./uasf.sh juice start && ./uasf.sh juice wait && \
      ./uasf.sh juice run --profile demo --out ./output/juice --lab-mode

Or manual URL once stack is reachable:

  ./uasf.sh juice url    # echoes suggested scope regex snippet

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DOCUMENTATION POINTER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ./uasf.sh run --help   narrow excerpt for scripted automation authors .
EOF
}

uasf_print_help_run_only() {
  printf '%s\n\n' "./uasf.sh run — focused flag reference (subset of full ./uasf.sh --help)"
  uasf_help_run_document
  cat <<'RFO'
━━━━━━━━ EXAMPLES ━━━━━━━━━
Non-interactive local bench:

  ./uasf.sh run \
    --target http://127.0.0.1:3000 \
    --scope-regex '^http://127\.0\.0\.1(:[0-9]+)?(/|$|[?])' \
    --profile demo \
    --out ./output/juice-run \
    --lab-mode \
    --waf-evasion standard

Re-open complete manual anytime:

  ./uasf.sh --help
RFO
}

uasf_cmd_validate_scenario() {
  local file="" target="" scope=""
  local allow_mut=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) file="$2"; shift 2 ;;
      --target) target="$2"; shift 2 ;;
      --scope-regex) scope="$2"; shift 2 ;;
      --allow-mutating-methods) allow_mut=1; shift ;;
      *) shift ;;
    esac
  done
  [[ -n "$file" ]] || uasf_die "--file required"
  target="${target:-http://127.0.0.1}"
  scope="${scope:-^http://127\.0\.0\.1}"
  uasf_validate_url_shape "$target" || uasf_die "bad target"
  UASF_VALIDATE_ALLOW_MUTATING="$allow_mut"
  uasf_validate_scenario_file "$file" "$target" "$scope"
}

uasf_cmd_dispatch_module() {
  local mid="$1"
  local tgt="$2"
  mid="${mid// /}"
  [[ -z "$mid" ]] && return 0

  local row found=0 labf methods risk
  for row in "${UASF_MODULE_ROWS[@]}"; do
    IFS='|' read -r iid disp cat risk meth sdef labf <<<"$row"
    if [[ "$iid" == "$mid" ]]; then
      found=1
      break
    fi
  done
  [[ "$found" -eq 1 ]] || { uasf_log WARN "Unknown module id: $mid"; return 0; }

  if [[ "$labf" == "1" ]] && [[ "${UASF_LAB_MODE:-0}" != "1" ]]; then
    uasf_log WARN "Skipping lab-only module without --lab-mode: $mid"
    return 0
  fi

  IFS=',' read -ra needm <<<"${meth// /}"
  local mcode
  for mcode in "${needm[@]}"; do
    [[ -z "$mcode" ]] && continue
    uasf_methods_allow "$mcode" || uasf_die "Profile method policy forbids '$mcode' (required by module $mid)"
  done

  local fn="uasf_run_module_${mid}"
  if declare -F "$fn" >/dev/null 2>&1; then
    uasf_run_echo ""
    uasf_run_echo "[module] ${mid}"
    "$fn" "$tgt"
  else
    uasf_log WARN "No runner for module: $mid"
  fi
}

uasf_cmd_run_parse() {
  local target=""
  local scope=""
  local profile=""
  local scenario=""
  local out=""
  local rps=""
  local to=""
  UASF_LAB_MODE=0
  UASF_I_UNDERSTAND=0
  UASF_ALLOW_MUTATING=0
  UASF_WRITE_HTML=0
  UASF_RUNTIME_VERBOSE=1
  local mods_custom=""
  local _waf_ev_explicit=0
  local dry_run=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target) target="$2"; shift 2 ;;
      --scope-regex) scope="$2"; shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      --scenario) scenario="$2"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      --rps) rps="$2"; shift 2 ;;
      --timeout) to="$2"; shift 2 ;;
      --lab-mode) UASF_LAB_MODE=1; shift ;;
      --i-understand) UASF_I_UNDERSTAND=1; shift ;;
      --allow-mutating-methods) UASF_ALLOW_MUTATING=1; shift ;;
      --html) UASF_WRITE_HTML=1; shift ;;
      --quiet) UASF_RUNTIME_VERBOSE=0; shift ;;
      --verbose) UASF_RUNTIME_VERBOSE=1; shift ;;
      --no-theme) UASF_THEME_OFF=1; shift ;;
      --modules) mods_custom="$2"; shift 2 ;;
      --dry-run) dry_run=1; shift ;;
      --waf-evasion)
        [[ $# -ge 2 ]] || uasf_die "--waf-evasion requires LEVEL (off|standard|lab)"
        UASF_WAF_EVASION="$2"
        _waf_ev_explicit=1
        shift 2
        ;;
      *) uasf_die "Unknown run option: $1" ;;
    esac
  done

  local plan_or_dry=0
  if [[ "${UASF_CLI_PLAN_INVOKED:-0}" == "1" ]] || [[ "$dry_run" == "1" ]]; then
    plan_or_dry=1
  fi

  [[ -n "$target" ]] || uasf_die "--target required"
  [[ -n "$scope" ]] || uasf_die "--scope-regex required"
  if [[ "$plan_or_dry" != "1" ]]; then
    [[ -n "$out" ]] || uasf_die "--out required"
  fi
  if [[ -z "${profile:-}" ]]; then
    if [[ -n "$scenario" ]]; then
      profile="scenario"
    else
      uasf_die "--profile required (use e.g. quick, demo, or scenario when using --scenario only)"
    fi
  fi

  target="${target%/}"
  if [[ "$plan_or_dry" != "1" ]]; then
    uasf_validate_out_dir "$out"
    mkdir -p "$out" || uasf_die "cannot mkdir $out"
  fi
  [[ "$to" =~ ^[0-9]+$ ]] || to="${UASF_DEFAULT_TIMEOUT:-10}"
  [[ "$rps" =~ ^[0-9]+$ ]] || rps="${UASF_DEFAULT_RPS:-2}"
  [[ "$to" -le "${UASF_SAFETY_MAX_TIMEOUT:-120}" ]] || uasf_die "--timeout exceeds safety max ${UASF_SAFETY_MAX_TIMEOUT}"
  UASF_RUNTIME_RPS="$rps"
  UASF_RUNTIME_TIMEOUT="$to"
  uasf_rate_limit_configure "$rps"

  UASF_SCOPE_REGEX="$scope"
  UASF_RUNTIME_TARGET="$target"
  UASF_RUNTIME_PROFILE="$profile"
  if [[ "${_waf_ev_explicit:-0}" != "1" ]] && [[ "${UASF_LAB_MODE:-0}" == "1" ]]; then
    UASF_WAF_EVASION="standard"
  elif [[ "${_waf_ev_explicit:-0}" != "1" ]]; then
    UASF_WAF_EVASION="${UASF_WAF_EVASION:-off}"
  fi
  UASF_WAF_EVASION="$(printf '%s' "${UASF_WAF_EVASION:-off}" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  case "$UASF_WAF_EVASION" in off | standard | lab) ;;
    *) uasf_die "--waf-evasion must be off, standard, or lab" ;;
  esac
  if [[ "$UASF_WAF_EVASION" == lab ]] && [[ "${UASF_LAB_MODE:-0}" != "1" ]]; then
    uasf_log WARN "waf-evasion tier 'lab' requires --lab-mode; using 'standard'"
    UASF_WAF_EVASION=standard
  fi

  UASF_RUNTIME_METHOD_POLICY=""
  export UASF_LAB_MODE UASF_SCOPE_REGEX UASF_RUNTIME_TARGET UASF_RUNTIME_TIMEOUT UASF_RUNTIME_RPS \
    UASF_ALLOW_MUTATING UASF_WRITE_HTML UASF_RUNTIME_PROFILE UASF_I_UNDERSTAND UASF_RUNTIME_VERBOSE UASF_WAF_EVASION

  local pfx=""
  pfx="${UASF_CORRELATION_PREFIX:-UASF}"
  UASF_CORRELATION_ID="${pfx}-360-$(date +%s)-$RANDOM"
  export UASF_CORRELATION_ID

  UASF_RUN_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  uasf_scope_classify_local "$target"
  if [[ "${UASF_I_UNDERSTAND:-0}" == "1" ]]; then
    export UASF_I_UNDERSTAND=1
  fi
  uasf_die_if_no_ack_nonlocal

  # Profile resolution
  uasf_profile_resolve "$profile"
  if [[ "${UASF_PROFILE_LAB_ONLY:-0}" == "1" ]] || [[ "$profile" == "full-lab" ]]; then
    [[ "${UASF_LAB_MODE:-0}" == "1" ]] || uasf_die "Profile $profile requires --lab-mode"
  fi

  if [[ "$profile" == "custom" ]]; then
    [[ -n "$mods_custom" ]] || uasf_die "custom profile needs --modules a,b,c"
    UASF_PROFILE_MODULES_RAW="$mods_custom"
  fi

  UASF_RUNTIME_METHOD_POLICY="${UASF_PROFILE_METHODS:-GET}"
  export UASF_RUNTIME_METHOD_POLICY

  [[ -z "${UASF_PROFILE_MODULES_RAW// /}" ]] && [[ "$profile" != "scenario" ]] && uasf_die "Profile '$profile' has empty modules"

  if [[ -n "$scenario" ]]; then
    [[ -f "$scenario" ]] || uasf_die "scenario not found: $scenario"
  fi

  if [[ "$plan_or_dry" == "1" ]]; then
    uasf_emit_run_plan_report "$target" "$scope" "$profile" "${scenario:-}" "${out:-}"
    exit 0
  fi

  uasf_run_init_artifacts "$out"

  if uasf_run_progress_enabled; then
    [[ "${UASF_THEME_OFF:-0}" != "1" ]] && uasf_theme_strip_run_header
    local _mods_line=""
    if [[ "$profile" != "scenario" ]]; then
      _mods_line="${UASF_PROFILE_MODULES_RAW// /}"
    elif [[ -n "${scenario:-}" ]]; then
      _mods_line="(scenario: $(basename "$scenario"))"
    fi
    uasf_run_echo "────────────────────────────────────────────────────────────"
    uasf_run_echo "UASF 360 run  correlation=${UASF_CORRELATION_ID}"
    uasf_run_echo "  target    ${target}"
    uasf_run_echo "  profile   ${profile}"
    [[ -z "$_mods_line" ]] || uasf_run_echo "  modules   ${_mods_line}"
    uasf_run_echo "  scope     ${scope}"
    uasf_run_echo "  bypass    ${UASF_WAF_EVASION}"
    uasf_run_echo "  out       ${out}"
    uasf_run_echo "────────────────────────────────────────────────────────────"
  fi

  if [[ -n "$scenario" ]]; then
    uasf_run_scenario_file "$scenario" "$target" "$UASF_ALLOW_MUTATING"
  else
    local list="${UASF_PROFILE_MODULES_RAW// /}"
    IFS=',' read -ra MIDS <<<"$list"
    local m
    for m in "${MIDS[@]}"; do
      uasf_cmd_dispatch_module "${m// /}" "$target"
    done
  fi

  uasf_write_run_manifest "$out"
  uasf_write_summary_md "$out"
  uasf_maybe_write_html_report "$out"
  uasf_emit_cli_post_run "$out"
}

uasf_cmd_vt() {
  if [[ $# -eq 0 ]]; then
    uasf_vt_list_templates
    return 0
  fi

  local sub="$1"
  case "$sub" in
    list)
      shift
      if [[ $# -eq 0 ]]; then
        uasf_vt_list_templates
      else
        # e.g. list with mistaken extra args → still run template --list safely
        uasf_vt_do template --list "$@"
      fi
      ;;
    start)
      shift
      uasf_vt_do start "$@"
      ;;
    stop)
      shift
      uasf_vt_do stop "$@"
      ;;
    *)
      uasf_vt_do "$@"
      ;;
  esac
}

uasf_cmd_juice() {
  case "${1:-help}" in
    help | -h | --help)
      uasf_juice_print_help
      ;;
    start)
      shift
      uasf_juice_start "$@"
      ;;
    stop)
      uasf_juice_stop
      ;;
    status)
      uasf_juice_status
      ;;
    logs)
      shift
      uasf_juice_logs "$@"
      ;;
    wait)
      shift
      uasf_juice_wait_http "$@"
      ;;
    url)
      uasf_juice_print_url_hint
      ;;
    run)
      shift
      uasf_cmd_present docker || uasf_die "docker required for juice run"
      if ! uasf_juice_is_running; then
        uasf_log INFO "Juice stack not running — starting with default port…"
        uasf_juice_start
      fi
      uasf_juice_wait_http
      exec </dev/null || true
      local _jb _jrx
      _jb="$(uasf_juice_base_url)"
      _jrx="$(uasf_derive_scope_regex_from_url "$_jb")" || uasf_die "could not derive scope for $_jb"
      uasf_cmd_run_parse --target "$_jb" --scope-regex "$_jrx" "$@"
      ;;
    *)
      uasf_die "unknown juice subcommand: $1 (try: ./uasf.sh juice help)"
      ;;
  esac
}

uasf_cmd_list_modules() {
  printf '%-22s %-28s %-16s %-10s %-14s %-12s %s\n' "module" "title" "category" "risk" "methods" "safe_default" "lab_only"
  local row
  for row in "${UASF_MODULE_ROWS[@]}"; do
    IFS='|' read -r id title cat risk meth sdef lab <<<"$row"
    printf '%-22s %-28s %-16s %-10s %-14s %-12s %s\n' "$id" "$title" "$cat" "$risk" "$meth" "$sdef" "$lab"
  done
}

uasf_cmd_list_scenarios() {
  local f
  for f in "${UASF_SCENARIO_DIR}"/*.json; do
    [[ -e "$f" ]] || continue
    if jq -e . "$f" >/dev/null 2>&1; then
      local nm ver
      nm=$(jq -r '.name' "$f")
      ver=$(uasf_scenario_detect_version "$f")
      echo "$(basename "$f") — $nm ($ver)"
    else
      echo "$(basename "$f") — INVALID JSON"
    fi
  done
}

uasf_cmd_init_dirs() {
  mkdir -p "${UASF_PKG_ROOT}/output" "${UASF_PKG_ROOT}/evidence" || true
  uasf_log INFO "Ensured ./output and ./evidence exist under ${UASF_PKG_ROOT}"
}

uasf_cmd_plan() {
  [[ "${1:-}" == run ]] || uasf_die "plan: unknown (use: plan run … then the same argv as ./uasf.sh run …)"
  shift
  UASF_CLI_PLAN_INVOKED=1 uasf_cmd_run_parse "$@"
}

uasf_cmd_explain_scope() {
  local target="" scope=""
  local samples=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target) target="$2"; shift 2 ;;
      --scope-regex) scope="$2"; shift 2 ;;
      --sample) samples+=("$2"); shift 2 ;;
      -h | --help)
        printf '%s\n\n' "explain-scope — exercise sample URLs against --scope-regex (same as probe gate: grep -Eq)"
        printf '%s\n' "  ./uasf.sh explain-scope --target BASE --scope-regex RX [--sample REL]…"
        exit 0
        ;;
      *) uasf_die "explain-scope: unknown option: $1" ;;
    esac
  done
  [[ -n "$target" ]] || uasf_die "--target required"
  [[ -n "$scope" ]] || uasf_die "--scope-regex required"
  target="${target%/}"
  uasf_validate_url_shape "$target" || uasf_die "bad --target URL shape"

  if [[ ${#samples[@]} -eq 0 ]]; then
    samples=('/' '/api/items/1' '/graphql' '?uasf_x=probe' '/login')
  fi

  printf '\n━━━━━━━━ explain-scope ━━━━━━━━\n'
  printf 'base URL:   %s\n' "$target"
  printf 'scope ERE:  %s\n' "$scope"
  local hint
  hint="$(uasf_derive_scope_regex_from_url "$target" 2>/dev/null || true)"
  [[ -n "$hint" ]] && printf 'auto cage:   %s\n' "$hint"
  printf '\n'

  local p url
  for p in "${samples[@]}"; do
    [[ -z "$p" ]] && continue
    if [[ "$p" == '/' ]]; then
      url="${target}/"
    elif [[ "${p:0:1}" == '/' ]]; then
      url="${target%/}${p}"
    elif [[ "${p:0:1}" == '?' ]]; then
      url="${target}/${p}"
    else
      url="${target}/${p}"
    fi
    if uasf_scope_match "$url" "$scope"; then
      printf 'MATCH     %s\n' "$url"
    else
      printf 'NO MATCH  %s\n' "$url"
    fi
  done
  printf '\nGate uses: echo URL | grep -Eq PATTERN (ERE, quiet).\n'
  printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
}

uasf_main_router() {
  if [[ $# -eq 0 ]] || [[ "$1" =~ ^(--help|-h|help)$ ]]; then
    uasf_print_help
    exit 0
  fi

  local cmd="$1"
  shift || true

  case "$cmd" in
    doctor)
      uasf_doctor
      if uasf_selftest_smoke; then echo "[selftest] basic scope sanity: ok"; fi
      ;;
    init) uasf_cmd_init_dirs ;;
    list-modules) uasf_cmd_list_modules ;;
    list-scenarios) uasf_cmd_list_scenarios ;;
    validate-scenario) uasf_cmd_validate_scenario "$@" ;;
    plan) uasf_cmd_plan "$@" ;;
    explain-scope) uasf_cmd_explain_scope "$@" ;;
    run)
      local _iflag=0
      local _rhelp=0
      local _filt=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --interactive | -i) _iflag=1; shift ;;
          --help | -h) _rhelp=1; shift ;;
          *) _filt+=("$1"); shift ;;
        esac
      done
      if [[ "$_rhelp" == "1" ]]; then
        uasf_print_help_run_only
        exit 0
      fi
      [[ "$_iflag" != "1" ]] && exec </dev/null || true
      if [[ "$_iflag" == "1" ]]; then
        uasf_cmd_run_interactive "${_filt[@]}"
      else
        uasf_cmd_run_parse "${_filt[@]}"
      fi
      ;;
    vt) uasf_cmd_vt "$@" ;;
    juice) uasf_cmd_juice "$@" ;;
    report)
      local rd=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --run) rd="$2"; shift 2 ;;
          *) shift ;;
        esac
      done
      [[ -n "$rd" ]] || uasf_die "report --run DIR required"
      uasf_regenerate_reports "$rd"
      ;;
    *)
      uasf_print_help
      exit 2
      ;;
  esac
}
