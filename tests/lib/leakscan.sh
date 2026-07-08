#!/usr/bin/env bash
# §6 — identifier / PII leak scan. See TESTING.md.
#
# Denylist = the resolved VALUES of exactly these chezmoi template variables,
# matched case-insensitively across the committed tree:
#     {{ .work.user }}  {{ .work.companyname }}  {{ .work.domain }}
#
# The values are never stored in the repo and never printed: they are taken from
# the environment (WORK_USER / WORK_COMPANYNAME / WORK_DOMAIN — how the in-apply
# preflight injects them via template) or, when absent, resolved at runtime via
# `chezmoi execute-template`. Findings report file:line + which variable matched,
# with the value redacted.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

section "identifier / PII leak scan"

# --- resolve the three denylist values (never echoed) -----------------------
resolve_var() { # <template> -> value on stdout
  [[ -n "${IN_PREFLIGHT:-}" ]] && return 0        # preflight must not call chezmoi
  have chezmoi || return 0
  chezmoi execute-template "$1" 2>/dev/null | head -1
}

# Parallel indexed arrays (macOS /bin/bash is 3.2 — no associative arrays).
DENY_KEYS=(work.user work.companyname work.domain)
DENY_VALS=(
  "${WORK_USER:-$(resolve_var '{{ .work.user }}')}"
  "${WORK_COMPANYNAME:-$(resolve_var '{{ .work.companyname }}')}"
  "${WORK_DOMAIN:-$(resolve_var '{{ .work.domain }}')}"
)

# --- file list to scan ------------------------------------------------------
scan_files() {
  if [[ -n "${SCAN_ROOT:-}" ]]; then
    find "$SCAN_ROOT" -type f -not -path '*/.git/*'
  elif have git && git -C "$REPO_ROOT" rev-parse >/dev/null 2>&1; then
    ( cd "$REPO_ROOT" && git ls-files )
  else
    find "$REPO_ROOT" -type f -not -path '*/.git/*'
  fi
}

# --- optional path allowlist (globs, one per line) --------------------------
ALLOW="$TESTS_DIR/leak_allowlist.txt"
is_allowlisted() {
  [[ -f "$ALLOW" ]] || return 1
  local f="$1" pat
  while IFS= read -r pat; do
    [[ -z "$pat" || "$pat" == \#* ]] && continue
    # shellcheck disable=SC2053
    [[ "$f" == $pat ]] && return 0
  done <"$ALLOW"
  return 1
}

redact() { # <value>  (reads a line on stdin, masks every case-insensitive match)
  local v="$1"
  if have perl; then
    V="$v" perl -pe 's/\Q$ENV{V}\E/****/gi'
  else
    cat >/dev/null; printf '(line hidden — install perl for redacted context)'
  fi
}

any_resolved=0
idx=0
for var in "${DENY_KEYS[@]}"; do
  val="${DENY_VALS[$idx]}"
  idx=$((idx + 1))
  # Guard: empty value must NOT match everything; too-short is unsafe to scan.
  [[ -n "$val" ]] || { note "$var resolved empty — skipped (non-work machine or unresolved)"; continue; }
  if [[ "${#val}" -lt 3 ]]; then
    warn "$var value is very short (<3 chars) — skipping to avoid false matches"
    continue
  fi
  any_resolved=1
  hit_for_var=0
  while IFS= read -r f; do
    [[ -f "$REPO_ROOT/$f" || -f "$f" ]] || continue
    path="$f"; [[ -f "$REPO_ROOT/$f" ]] && path="$REPO_ROOT/$f"
    is_allowlisted "$f" && continue
    # -I skips binary files; -F fixed string; -i case-insensitive; -n line numbers
    while IFS=: read -r lineno line; do
      [[ -n "$lineno" ]] || continue
      hit_for_var=1
      masked="$(printf '%s' "$line" | redact "$val" 2>/dev/null || printf '(context hidden)')"
      fail "[$var] leaked in $f:$lineno    $masked"
    done < <(grep -IniF -- "$val" "$path" 2>/dev/null || true)
  done < <(scan_files)
  [[ "$hit_for_var" -eq 0 ]] && pass "no occurrences of $var value in the tree"
done

if [[ "$any_resolved" -eq 0 ]]; then
  warn "no denylist values resolved — leak scan did not run (set WORK_USER/WORK_COMPANYNAME/WORK_DOMAIN or sign in to 1Password)"
fi

summary_exit
