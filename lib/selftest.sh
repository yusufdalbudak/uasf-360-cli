#!/usr/bin/env bash
# shellcheck shell=bash

uasf_selftest_smoke() {
  UASF_SCOPE_REGEX='^https://example\.com'
  UASF_RUNTIME_TARGET="https://example.com"
  uasf_scope_classify_local "https://example.com" || true
  uasf_scope_match "https://example.com/path" '^https://example\.com' || return 1
  return 0
}
