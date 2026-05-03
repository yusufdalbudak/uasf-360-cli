#!/usr/bin/env bash
# shellcheck shell=bash

uasf_write_run_manifest() {
  local out="$1"
  local ver=""
  [[ -f "${UASF_PKG_ROOT}/VERSION" ]] && ver=$(tr -d '\n' <"${UASF_PKG_ROOT}/VERSION")
  jq -nc \
    --arg ver "$ver" \
    --arg corr "${UASF_CORRELATION_ID:-}" \
    --arg tgt "${UASF_RUNTIME_TARGET:-}" \
    --arg rx "${UASF_SCOPE_REGEX:-}" \
    --arg started "${UASF_RUN_STARTED:-}" \
    --arg profile "${UASF_RUNTIME_PROFILE:-}" \
    '{
       framework:"uasf-360-cli",
       version:$ver,
       correlation_id:$corr,
       target:$tgt,
       scope_regex:$rx,
       started_iso:$started,
       profile:$profile
     }' >"${out}/run.json"
}

uasf_write_summary_md() {
  local out="$1"
  local csv="$out/results.csv"
  local total="0"
  if [[ -f "$csv" ]]; then
    total=$(($(wc -l <"$csv" | tr -d ' ') - 1))
    [[ "$total" -lt 0 ]] && total=0
  fi
  {
    printf '# UASF 360 CLI — Run summary\n\n'
    printf 'Target: `%s`\n\n' "${UASF_RUNTIME_TARGET:-unknown}"
    printf 'Correlation: `%s`\n\n' "${UASF_CORRELATION_ID:-}"
    printf 'Evidence: `%s/evidence`\n\n' "$out"
    printf 'Requests recorded: **%s**\n\n' "$total"
    printf 'Artifacts: `results.csv`, `results.ndjson`, `audit.log`, `run.json`\n'
  } >"${out}/summary.md"

  local nd="${out}/results.ndjson"
  if [[ -f "$nd" ]] && [[ -s "$nd" ]]; then
    {
      jq -rs '
        [.[] | select(.schema == "uasf.event.v1")] as $e
        | if ($e | length) == 0 then empty else
            "## Verdict distribution\n\n| Verdict | Count |\n|---:|---:|\n"
            + (($e | group_by(.verdict) | sort_by(-length)
                | map("| \(.[0].verdict) | \(length) |") | join("\n")))
            + "\n\n## Probes by module\n\n| Module | Count |\n|---:|---:|\n"
            + (($e | group_by(.module) | sort_by(-length)
                | map("| \(.[0].module) | \(length) |") | join("\n")))
            + "\n"
          end
      ' "$nd" 2>/dev/null || true
    } >>"${out}/summary.md"
  fi

  uasf_append_waap_reading_to_summary "$out" || true
}

# Append short interpretation when CVE-class probes show uniform edge blocking (NDJSON).
uasf_append_waap_reading_to_summary() {
  local out="${1:?}"
  local nd="${out}/results.ndjson"
  [[ -f "$nd" ]] && [[ -s "$nd" ]] || return 0
  local blk
  blk=$(
    jq -sr '
      [.[] | select(.schema == "uasf.event.v1" and .module == "cve_signature_probes")] as $p
      | if (($p | length) < 5) then empty
        else
          ($p | map(.verdict) | unique | length) as $vn
          | ($p | map(.http_code) | unique | length) as $cn
          | if ($vn == 1) and ($cn == 1) then
              ($p[0].verdict) as $v | ($p[0].http_code) as $c
              | ($p | length) as $n
              | ($p | map(.waf_vendor) | unique | join(", ") | if . == "" then "—" else . end) as $wf
              | "## WAAP reading (`cve_signature_probes`)\n\n"
              + "- All **\($n)** probes shared verdict **`\($v)`** and HTTP **`\($c)`**"
              + " (vendor hints: `\($wf)`).\n"
              + "- **Meaning:** the edge consistently matched these **CVE-class signature strings**. Vendor demos such as AppTrana are wired to showcase that blocking.\n"
              + "- **Gap analysis (authorized lab):** use `--lab-mode --waf-evasion lab` to hit **alt query param**, **custom header**, and **Cookie** for the same lines; diverging `http_code` / `verdict` in `results.ndjson` points to parser or policy imbalance.\n"
            else empty end
        end
    ' "$nd" 2>/dev/null || true
  )
  [[ -n "${blk:-}" ]] || return 0
  printf '\n%s\n' "$blk" >>"${out}/summary.md"
}

# After Phase 1 (probe run): print consolidated summary, tail audit, Phase 2 bridge.
uasf_emit_cli_post_run() {
  local out="${1:?}"
  local corr="${UASF_CORRELATION_ID:-}"
  if ! uasf_run_progress_enabled; then
    printf '[UASF 360] run complete → %s  ( correlation %s | open summary.md )\n' "$out" "$corr" >&2
    return 0
  fi

  uasf_run_echo ""
  uasf_run_echo "════════════════════════════════════════════════════════════"
  uasf_run_echo " Phase 1 — validation probes finished (observability & control checks)"
  uasf_run_echo "════════════════════════════════════════════════════════════"
  uasf_run_echo ""

  [[ -f "${out}/summary.md" ]] && cat "${out}/summary.md" >&2

  uasf_run_echo ""
  uasf_run_echo "── Recent audit (last 15 lines) ──"
  if [[ -f "${out}/audit.log" ]]; then
    tail -n 15 "${out}/audit.log" >&2 || true
  else
    uasf_run_echo "  (no audit.log)"
  fi

  uasf_run_echo ""
  uasf_run_echo "── Evidence directory (latest files) ──"
  local ev="${out}/evidence"
  if [[ -d "$ev" ]] && ls -t "$ev" >/dev/null 2>&1; then
    local ec
    ec=$(find "$ev" -type f 2>/dev/null | wc -l | tr -d ' ')
    uasf_run_echo "  files: ${ec}"
    while IFS= read -r bf || true; do
      [[ -z "$bf" ]] && continue
      uasf_run_echo "  • ${bf}"
    done < <(ls -t "$ev" 2>/dev/null | head -12 || true)
  else
    uasf_run_echo "  (no evidence dir)"
  fi

  uasf_run_echo ""
  uasf_run_echo "── WAAP interpretation (cve_signature_probes) ──"
  uasf_emit_waap_reading_hints_cli "$out" || true

  uasf_run_echo ""
  uasf_run_echo "── Result rows (recent, abbreviated URL) ──"
  local nd="${out}/results.ndjson"
  if [[ -f "$nd" ]] && [[ -s "$nd" ]]; then
    while IFS=$'\t' read -r m ver c ms u || true; do
      [[ -z "${m:-}" ]] && [[ -z "${ver:-}" ]] && continue
      uasf_run_echo "  ${m:-?} │ ${ver:-?} │ http=${c:-} │ ${ms:-?}ms │ ${u:-}"
    done < <(
      jq -sr '
        [.[] | select(.schema == "uasf.event.v1")] as $ev
        | if (($ev | length) == 0) then empty
          else
            ($ev | .[-15:][]
              | [.module,.verdict,.http_code,.duration_ms,
                 (.target_url | if length > 92 then .[0:90] + "…" else . end)]
              | @tsv)
          end
      ' "$nd" 2>/dev/null || true
    )
    uasf_run_echo ""
    uasf_run_echo "  Full structured stream: jq '.' \"${nd}\""
  else
    uasf_run_echo "  (no NDJSON)"
  fi

  uasf_run_echo ""
  uasf_run_echo "════════════════════════════════════════════════════════════"
  uasf_run_echo " Phase 2 — follow-through (consume Phase 1 artifacts)"
  uasf_run_echo "════════════════════════════════════════════════════════════"
  uasf_run_echo ""
  uasf_run_echo "  • WAAP/SIEM: filter requests bearing header \`X-UASF-Correlation: ${corr}\`"
  uasf_run_echo "  • Structured feed for downstream tooling: ${out}/results.ndjson"
  uasf_run_echo "  • Regenerate snapshot: ./uasf.sh report --run ${out}"
  uasf_run_echo "  • Use the same scoped target + tightened scenarios for authorized deeper tests;"
  uasf_run_echo "    ingest verdicts/modules above — do not widen scope beyond policy."
  uasf_run_echo ""
  uasf_run_echo "── Finished · process exiting (nothing left running on this tty) ──"
}

# Echo the same cve_signature_probes uniformity analysis (stderr) for quick human scan.
uasf_emit_waap_reading_hints_cli() {
  local out="${1:?}"
  local nd="${out}/results.ndjson"
  [[ -f "$nd" ]] && [[ -s "$nd" ]] || {
    uasf_run_echo "  (no results.ndjson yet)"
    return 0
  }
  local hint
  hint=$(
    jq -sr '
      [.[] | select(.schema == "uasf.event.v1" and .module == "cve_signature_probes")] as $p
      | if (($p | length) < 5) then
          "  Too few cve_signature_probes rows for a dominance read (need ≥5)."
        else
          ($p | map(.verdict) | unique | length) as $vn
          | ($p | map(.http_code) | unique | length) as $cn
          | if ($vn == 1) and ($cn == 1) then
              ($p[0].verdict) as $v | ($p[0].http_code) as $c | ($p | length) as $n
              | "  Uniform result: \($n) probes → \($v) / HTTP \($c). The WAAP is catching these signatures on the tested channel(s). "
              + "That validates policy on a demo like AppTrana; it is not a bypass failure. "
              + "For channel comparison, re-run with --lab-mode --waf-evasion lab (header + Cookie + alt query param)."
            else
              "  Mixed verdicts or HTTP codes across cve_signature_probes — compare rows in results.ndjson by target_url (query vs header vs cookie)."
            end
        end
    ' "$nd" 2>/dev/null || printf '%s' "  (jq parse skip)"
  )
  uasf_run_echo "$hint"
}

uasf_maybe_write_html_report() {
  local out="$1"
  [[ "${UASF_WRITE_HTML:-0}" == "1" ]] || return 0
  local csv="$out/results.csv"
  [[ -f "$csv" ]] || return 0
  {
    printf '%s\n' '<!doctype html><meta charset=utf-8><title>UASF 360 CLI offline report</title>'
    printf '%s\n' '<style>body{font-family:system-ui;max-width:1200px;margin:24px}table{border-collapse:collapse}'
    printf '%s\n' 'td,th{border:1px solid #ccc;padding:6px;text-align:left}</style>'
    printf '<h1>UASF 360 CLI</h1><p>Offline artifact — correlation <code>%s</code></p>\n' "${UASF_CORRELATION_ID:-}"
    printf '%s\n' '<h2>Results (truncated CSV)</h2><pre>'
    head -100 "$csv" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'
    printf '%s\n' '</pre></body>'
  } >"${out}/report.html"
}

uasf_regenerate_reports() {
  local run_dir="$1"
  [[ -d "$run_dir" ]] || { uasf_log ERROR "run dir missing: $run_dir"; return 1; }
  [[ -f "$run_dir/results.ndjson" ]] || [[ -f "$run_dir/results.csv" ]] || {
    uasf_log WARN "no results in $run_dir"
    return 1
  }
  {
    printf '# Regenerated snapshot\n'
    printf 'UTC: `%s`\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if [[ -f "$run_dir/results.ndjson" ]]; then
      printf 'NDJSON lines: `%s`\n' "$(wc -l <"$run_dir/results.ndjson" | tr -d ' ')"
    fi
  } >"${run_dir}/summary.regenerated.md"
  printf 'Wrote summary.regenerated.md for %s\n' "$run_dir"
}
