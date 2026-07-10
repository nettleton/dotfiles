#!/usr/bin/env bash
# Phase-1 test runner. Runs the reusable check scripts in tests/lib/ and reports
# an aggregate pass/fail. See TESTING.md.
#
# Usage:
#   tests/run.sh [--offline] [--audit-all] [check ...]
#     --offline    skip network checks (existence, security audit)
#     --audit-all  run the abandonment/CVE audit over ALL packages (slow)
#     check ...    subset of: schema render lint exist security prune leak
#                  (default: all)
#
# Exit code is non-zero if any selected check fails.

set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

offline=0
audit_all=0
checks=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) offline=1; shift ;;
    --audit-all) audit_all=1; shift ;;
    schema|render|lint|exist|security|prune|leak) checks+=("$1"); shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ "${#checks[@]}" -eq 0 ]] && checks=(schema render lint exist security prune leak)

rc=0
# Side-channel: each check's summary_exit appends its collected FAIL/WARN
# messages here (labeled), so we can print ONE consolidated issue list at the
# end without parsing colored output.
SUMMARY_FILE="$(mktemp -t chezmoi-tests-summary.XXXXXX)"
export SUMMARY_FILE
trap 'rm -f "$SUMMARY_FILE"' EXIT

run() { # <label> <script> [args...]
  local label="$1"; shift
  printf '\n\033[1m### %s\033[0m\n' "$label"
  if SUMMARY_LABEL="$label" bash "$@"; then
    printf '\033[32m### %s: PASS\033[0m\n' "$label"
  else
    printf '\033[31m### %s: FAIL\033[0m\n' "$label"
    rc=1
  fi
}

for c in "${checks[@]}"; do
  case "$c" in
    schema)   run "A3 schema"   "$LIB/check_packages_schema.sh" ;;
    render)   run "A1 render"   "$LIB/check_render.sh" ;;
    lint)     run "A2 lint"     "$LIB/check_lint.sh" ;;
    exist)    [[ "$offline" -eq 1 ]] && { echo "(skipping exist — offline)"; continue; }
              run "A4 existence" "$LIB/check_packages_exist.sh" ;;
    security) [[ "$offline" -eq 1 ]] && { echo "(skipping security — offline)"; continue; }
              if [[ "$audit_all" -eq 1 ]]; then run "A7 security" "$LIB/check_security.sh" --all
              else run "A7 security" "$LIB/check_security.sh"; fi ;;
    prune)    run "B2 prune-guard" "$LIB/prune_guard.sh" ;;
    leak)     run "§6 leak scan"   "$LIB/leakscan.sh" ;;
  esac
done

# Consolidated, labeled issue list across all checks (each message was already
# printed inline and in its check's own summary — this is the action list).
if [[ -s "$SUMMARY_FILE" ]]; then
  printf '\n\033[1m==== issues to action ====\033[0m\n'
  while IFS='|' read -r kind label msg; do
    [[ "$kind" == FAIL ]] && printf '  \033[31m✗ FAIL\033[0m [%s] %s\n' "$label" "$msg"
  done <"$SUMMARY_FILE"
  while IFS='|' read -r kind label msg; do
    [[ "$kind" == WARN ]] && printf '  \033[33m⚠ WARN\033[0m [%s] %s\n' "$label" "$msg"
  done <"$SUMMARY_FILE"
fi

printf '\n\033[1m==== overall: %s ====\033[0m\n' "$([[ $rc -eq 0 ]] && echo PASS || echo FAIL)"
exit "$rc"
