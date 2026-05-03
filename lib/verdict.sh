#!/usr/bin/env bash
# shellcheck shell=bash
# Classification for defensive WAAP/WAF validation (no “exploit” wording)

uasf_verdict_for_response() {
  local code="$1"
  local header_file="$2"
  local body_sample_file="$3"
  local blocked_codes_csv="${4:-403,406,418,451}"
  local allowed_codes_csv="${5:-200,201,202,204}"
  local challenge_patterns="${6:-captcha|access denied|blocked|challenge|sorry, you have been blocked}"
  local lab_mode="${7:-0}"

  local fused=""
  if [[ -f "$header_file" ]]; then fused="$(cat "$header_file" 2>/dev/null)"; fi
  fused+="$(head -c 8192 "$body_sample_file" 2>/dev/null || true)"

  if [[ "$code" == "000" ]]; then
    printf '%s\n' "ERROR"; return 0
  fi
  if printf '%s' "$code" | grep -Eq '^3[0-9][0-9]$'; then
    printf '%s\n' "REDIRECTED"; return 0
  fi
  if printf '%s' "$code" | grep -Eq '^404$|^410$'; then
    printf '%s\n' "NOT_FOUND"; return 0
  fi
  if printf '%s' "$code" | grep -Eq '^429$'; then
    printf '%s\n' "RATE_LIMITED"; return 0
  fi

  local bc
  IFS=',' read -ra bc <<<"${blocked_codes_csv// /}"
  local codenum="${code}"
  local hitb=0
  for x in "${bc[@]:-}"; do
    [[ "$codenum" == "$x" ]] && hitb=1 && break
  done
  if [[ $hitb -eq 1 ]] || printf '%s' "$code" | grep -Eq '^5[0-9][0-9]$'; then
    printf '%s\n' "BLOCKED"; return 0
  fi

  if printf '%s' "$code" | grep -Eq '^401$|^407$'; then
    printf '%s\n' "CHALLENGED"; return 0
  fi

  if printf '%s' "$code" | grep -Eq '^403$'; then
    printf '%s\n' "BLOCKED"; return 0
  fi

  if printf '%s' "$code" | grep -Eq '^4[1-9][0-9]$'; then
    printf '%s\n' "BLOCKED"; return 0
  fi

  if printf '%s' "$code" | grep -Eq '^2[0-9][0-9]$'; then
    if printf '%s' "$fused" | grep -Eiq "${challenge_patterns}"; then
      printf '%s\n' "CHALLENGED"; return 0
    fi
  fi

  local al
  IFS=',' read -ra al <<<"${allowed_codes_csv// /}"
  local hita=0
  for x in "${al[@]:-}"; do [[ "$codenum" == "$x" ]] && hita=1 && break; done
  if [[ $hita -eq 1 ]] && printf '%s' "$code" | grep -Eq '^2[0-9][0-9]$'; then
    if [[ "$lab_mode" == "1" ]] && printf '%s' "$fused" | grep -Eiq 'uasf-lab-marker|lab-confirmed-marker'; then
      printf '%s\n' "LAB_CONFIRMED"; return 0
    fi
    if printf '%s' "$fused" | grep -Eiq "${challenge_patterns}"; then
      printf '%s\n' "CHALLENGED"; return 0
    fi
    printf '%s\n' "ALLOWED"; return 0
  fi

  if printf '%s' "$code" | grep -Eq '^2[0-9][0-9]$'; then
    if [[ "$lab_mode" == "1" ]] && printf '%s' "$fused" | grep -Eiq 'uasf-lab-marker|lab-confirmed-marker'; then
      printf '%s\n' "LAB_CONFIRMED"; return 0
    fi
    printf '%s\n' "ALLOWED"; return 0
  fi

  printf '%s\n' "INCONCLUSIVE"; return 0
}
