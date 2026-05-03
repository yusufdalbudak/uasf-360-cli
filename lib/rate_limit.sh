#!/usr/bin/env bash
# shellcheck shell=bash
# Simple sleep-based pacing (requests per second)

UASF_RATE_LAST_TICK_MS=0

uasf_rate_limit_configure() {
  local rps="$1"
  local max="${UASF_SAFETY_MAX_RPS:-20}"
  if [[ ! "$rps" =~ ^[0-9]+$ ]] || [[ "$rps" -le 0 ]]; then
    uasf_die "Invalid RPS: $rps"
  fi
  if [[ "$rps" -gt "$max" ]]; then
    uasf_die "RPS $rps exceeds configured maximum $max"
  fi
}

uasf_rate_limit_sleep_tick() {
  local rps="${UASF_RUNTIME_RPS:?}"
  if [[ "$rps" -eq 0 ]]; then return 0; fi
  local now
  now=$(uasf_now_ms)
  local min_gap=$((1000 / rps))
  if [[ "${UASF_RATE_LAST_TICK_MS:-0}" -eq 0 ]]; then
    UASF_RATE_LAST_TICK_MS=$now
    return 0
  fi
  local elapsed=$((now - UASF_RATE_LAST_TICK_MS))
  if [[ "$elapsed" -lt "$min_gap" ]]; then
    local nap_ms=$((min_gap - elapsed))
    local nap_sec
    nap_sec=$(awk -v ms="$nap_ms" 'BEGIN { printf "%f", ms/1000 }')
    sleep "$nap_sec"
    now=$(uasf_now_ms)
  fi
  UASF_RATE_LAST_TICK_MS=$now
}
