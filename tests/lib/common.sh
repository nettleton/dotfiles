#!/usr/bin/env bash
# Shared helpers for the chezmoi dotfiles test suite (see TESTING.md).
# Source this at the top of every check script:
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#
# Provides: repo/path vars, colored pass/warn/fail logging with counters, a
# `have` tool check, and `summary_exit` (exit 1 iff any failures were recorded).

set -euo pipefail

# --- paths ------------------------------------------------------------------
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$LIB_DIR/.." && pwd)"
# Repo root: overridable so the in-apply preflight can pass the hardcoded
# $HOME/.local/share/chezmoi path (it must NOT call `chezmoi source-path`).
REPO_ROOT="${CHEZMOI_REPO:-$(cd "$TESTS_DIR/.." && pwd)}"
PACKAGES_YAML="${PACKAGES_YAML:-$REPO_ROOT/.chezmoidata/packages.yaml}"

# --- colors -----------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_DIM=$'\033[2m'; C_BLD=$'\033[1m'; C_RST=$'\033[0m'
else
  C_RED=''; C_GRN=''; C_YEL=''; C_DIM=''; C_BLD=''; C_RST=''
fi

# --- findings counters + collected messages ---------------------------------
# Messages are printed inline where they occur (debug context) AND collected
# for a consolidated re-print in summary_exit (actionability). When run.sh
# sets SUMMARY_FILE/SUMMARY_LABEL, they are also appended there so the runner
# can print one cross-script issue list at the very end.
FAIL_COUNT=0
WARN_COUNT=0
FAIL_MSGS=()
WARN_MSGS=()

section() { printf '\n%s== %s ==%s\n' "$C_BLD" "$*" "$C_RST"; }
pass()    { printf '  %s✓%s %s\n' "$C_GRN" "$C_RST" "$*"; }
note()    { printf '  %s· %s%s\n' "$C_DIM" "$*" "$C_RST"; }
warn()    { WARN_COUNT=$((WARN_COUNT + 1)); WARN_MSGS+=("$*"); printf '  %s⚠ WARN%s %s\n' "$C_YEL" "$C_RST" "$*"; }
fail()    { FAIL_COUNT=$((FAIL_COUNT + 1)); FAIL_MSGS+=("$*"); printf '  %s✗ FAIL%s %s\n' "$C_RED" "$C_RST" "$*"; }

# Keep brew output deterministic & fast for parsing (no auto-update mid-run, no
# interactive hints). Harmless when brew is absent.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

have() { command -v "$1" >/dev/null 2>&1; }

die() { printf '%sfatal:%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 2; }

# Exit 0 if no failures were recorded, 1 otherwise. Warnings never fail.
# Re-prints every collected failure/warning as a consolidated block (the same
# messages already shown inline), then the counts.
summary_exit() {
  local m
  if [[ "$FAIL_COUNT" -gt 0 || "$WARN_COUNT" -gt 0 ]]; then
    printf '\n%s-- issues --%s\n' "$C_BLD" "$C_RST"
    if [[ "$FAIL_COUNT" -gt 0 ]]; then
      for m in "${FAIL_MSGS[@]}"; do printf '  %s✗ FAIL%s %s\n' "$C_RED" "$C_RST" "$m"; done
    fi
    if [[ "$WARN_COUNT" -gt 0 ]]; then
      for m in "${WARN_MSGS[@]}"; do printf '  %s⚠ WARN%s %s\n' "$C_YEL" "$C_RST" "$m"; done
    fi
  fi
  # Side-channel for run.sh's cross-script consolidated list (plain text).
  if [[ -n "${SUMMARY_FILE:-}" ]]; then
    if [[ "$FAIL_COUNT" -gt 0 ]]; then
      for m in "${FAIL_MSGS[@]}"; do printf 'FAIL|%s|%s\n' "${SUMMARY_LABEL:-?}" "$m" >>"$SUMMARY_FILE"; done
    fi
    if [[ "$WARN_COUNT" -gt 0 ]]; then
      for m in "${WARN_MSGS[@]}"; do printf 'WARN|%s|%s\n' "${SUMMARY_LABEL:-?}" "$m" >>"$SUMMARY_FILE"; done
    fi
  fi
  printf '\n%s%d failure(s), %d warning(s).%s\n' \
    "$C_BLD" "$FAIL_COUNT" "$WARN_COUNT" "$C_RST"
  [[ "$FAIL_COUNT" -eq 0 ]]
}

# Guard: every check script needs the package data and yq.
require_packages_yaml() {
  [[ -f "$PACKAGES_YAML" ]] || die "packages.yaml not found at $PACKAGES_YAML"
  have yq || die "yq (mikefarah v4) is required — install with: brew install yq"
}
