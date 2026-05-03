#!/usr/bin/env bash
# shellcheck shell=bash
# Load non-comment lines from payload files (safe-by-default text probes)

uasf_urlencode() {
  local string="${1:-}"
  local strlen=${#string}
  local encoded=""
  local pos c o
  for ((pos = 0; pos < strlen; pos++)); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9]) o="$c" ;;
      *) printf -v o '%%%02X' "'$c" ;;
    esac
    encoded+="$o"
  done
  printf '%s' "$encoded"
}

uasf_payload_lines() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$'
}

uasf_expand_path_token() {
  local template="$1"
  local payload="$2"
  printf '%s' "${template//\{\{payload\}\}/$payload}"
}
