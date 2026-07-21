#!/usr/bin/env bash
# A7 — package security & maintenance audit. Network. See TESTING.md §5.
#
# Signals, cheapest/most-authoritative first:
#   1. Homebrew deprecation/disable  — ALL packages. disabled => FAIL, deprecated => WARN.
#   2. Abandonment (archived / stale) — NEWLY ADDED packages, via GitHub. WARN.
#   3. CVEs                           — NEWLY ADDED packages, via OSV. best-effort.
#
# "Newly added" = brew/cask tokens present now but absent at $AUDIT_BASE (default
# HEAD). Pass --all to run the added-only checks over every package.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"
require_packages_yaml
have curl || die "curl is required for the security audit"
have jq   || die "jq is required for the security audit"

AUDIT_BASE="${AUDIT_BASE:-HEAD}"
STALE_MONTHS="${STALE_MONTHS:-18}"
AUDIT_ALL=0
[[ "${1:-}" == "--all" ]] && AUDIT_ALL=1

kind_of() { grep -qxF "$1" <(pkg_all_casks) && echo cask || echo formula; }

# Deprecations consciously accepted (downgraded WARN -> note). DISABLED is never
# allowlisted — a disabled package can't be installed, so it always fails.
DEPRECATION_ALLOW="$TESTS_DIR/deprecation_allowlist.txt"
dep_allowlisted() {
  [[ -f "$DEPRECATION_ALLOW" ]] || return 1
  grep -vE '^[[:space:]]*(#|$)' "$DEPRECATION_ALLOW" | grep -qxF "$1"
}

# --- read deprecated/disabled for one package -> "DEP DIS" (true/false) ------
dep_flags() {
  local kind="$1" name="$2" sel path rc j
  [[ "$kind" == cask ]] && sel='.casks[0]' || sel='.formulae[0]'
  if is_tapped "$name"; then
    have brew || { echo "unknown unknown"; return; }
    if [[ "$kind" == cask ]]; then
      j=$(brew info --json=v2 --cask "$name" 2>/dev/null) || { echo "unknown unknown"; return; }
    else
      j=$(brew info --json=v2 "$name" 2>/dev/null) || { echo "unknown unknown"; return; }
    fi
    printf '%s %s\n' "$(jq -r "$sel.deprecated // false" <<<"$j")" "$(jq -r "$sel.disabled // false" <<<"$j")"
  else
    path=$(brew_api_fetch "$kind" "$name"); rc=$?
    [[ $rc -eq 0 ]] || { echo "unknown unknown"; return; }
    printf '%s %s\n' "$(jq -r '.deprecated // false' "$path")" "$(jq -r '.disabled // false' "$path")"
  fi
}

section "Homebrew deprecation / disable (all packages)"
audit_dep() {
  local kind="$1" name="$2" flags dep dis
  read -r dep dis < <(dep_flags "$kind" "$name")
  if [[ "$dis" == true ]]; then
    fail "$kind '$name' is DISABLED upstream — must be replaced or removed"
  elif [[ "$dep" == true ]]; then
    if dep_allowlisted "$name"; then
      note "$kind $name is deprecated upstream — accepted (deprecation_allowlist)"
    else
      warn "$kind '$name' is deprecated upstream — plan a replacement"
    fi
  elif [[ "$dep" == unknown ]]; then
    note "$kind $name — deprecation status unknown (tapped/offline)"
  else
    pass "$kind $name"
  fi
}
while IFS= read -r b; do [[ -n "$b" ]] && audit_dep formula "$b"; done < <(pkg_all_brews)
while IFS= read -r c; do [[ -n "$c" ]] && audit_dep cask "$c"; done < <(pkg_all_casks)

# --- determine newly-added tokens -------------------------------------------
current_tokens() { { pkg_all_brews; pkg_all_casks; } | sort -u; }
base_tokens() {
  git -C "$REPO_ROOT" show "$AUDIT_BASE:.chezmoidata/packages.yaml" 2>/dev/null \
    | yq '.packages.brew.brews[], .packages.brew.personal_brews[], .packages.brew.casks[], .packages.brew.personal_casks[]' 2>/dev/null \
    | sort -u
}

# macOS /bin/bash is 3.2 — no mapfile; read into an indexed array.
new_tokens=()
if [[ "$AUDIT_ALL" -eq 1 ]]; then
  section "abandonment + CVE audit (ALL packages, --all)"
  while IFS= read -r line; do [[ -n "$line" ]] && new_tokens+=("$line"); done < <(current_tokens)
else
  section "abandonment + CVE audit (packages added vs $AUDIT_BASE)"
  while IFS= read -r line; do [[ -n "$line" ]] && new_tokens+=("$line"); done < <(comm -23 <(current_tokens) <(base_tokens))
fi

if [[ "${#new_tokens[@]}" -eq 0 ]]; then
  note "no newly-added packages to audit (use --all to audit everything)"
  summary_exit; exit
fi

# --- GitHub repo extraction + abandonment -----------------------------------
gh_repo_of() { # <kind> <name> -> owner/repo (or empty)
  local kind="$1" name="$2" path
  is_tapped "$name" && return 0
  path=$(brew_api_fetch "$kind" "$name") || true
  [[ -s "$path" ]] || return 0
  jq -r '[.homepage, .urls.head.url, .urls.stable.url] | map(select(. != null)) | .[]' "$path" 2>/dev/null \
    | grep -oiE 'github\.com[/:][^/]+/[^/ ".]+' | head -1 \
    | sed -E 's#github\.com[/:]##I; s#\.git$##'
}

audit_abandonment() {
  local kind="$1" name="$2" repo meta archived pushed months
  have gh || { note "$name — abandonment check skipped (gh not installed)"; return; }
  repo=$(gh_repo_of "$kind" "$name")
  [[ -n "$repo" ]] || { note "$name — no GitHub upstream resolved"; return; }
  meta=$(gh api "repos/$repo" 2>/dev/null) || { note "$name — gh api repos/$repo failed (auth/rate/404)"; return; }
  archived=$(jq -r '.archived // false' <<<"$meta")
  pushed=$(jq -r '.pushed_at // empty' <<<"$meta")
  if [[ "$archived" == true ]]; then
    warn "$kind '$name' upstream ($repo) is ARCHIVED — unmaintained"
    return
  fi
  if [[ -n "$pushed" ]]; then
    local psec now
    psec=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$pushed" +%s 2>/dev/null || date -d "$pushed" +%s 2>/dev/null || echo 0)
    now=$(date +%s)
    months=$(( (now - psec) / 2629800 ))
    if [[ "$psec" -gt 0 && "$months" -ge "$STALE_MONTHS" ]]; then
      warn "$kind '$name' upstream ($repo) — no push in ~${months}mo (>= ${STALE_MONTHS}mo)"
    else
      pass "$kind $name upstream ($repo) active (~${months}mo since last push)"
    fi
  fi
}

# --- CVE scan via `brew vulns` (core Homebrew command; OSV GIT ecosystem) -----
# Purpose-built: maps each formula to its upstream repo, queries OSV, and marks
# CVEs already patched by the formula as resolved (fewer false positives). We
# scan the given formulae in one call; high/critical => FAIL. Casks are not
# covered (formula-source-repo based), so they are excluded.
#
# `brew vulns` was merged into Homebrew/brew as a built-in command (the
# homebrew/brew-vulns tap is archived) — so it's a `brew` subcommand now, not a
# `brew-vulns` executable on PATH. Availability = a recent enough brew.
brew_vulns_available() {
  brew commands 2>/dev/null | grep -qx vulns
}
audit_cve_brewvulns() {
  local formulae=("$@")
  [[ "${#formulae[@]}" -gt 0 ]] || return 0
  if ! brew_vulns_available; then
    note "CVE scan skipped — 'brew vulns' unavailable; update Homebrew (brew update)"
    return 0
  fi
  local out rc
  out=$(brew vulns --severity high "${formulae[@]}" 2>&1); rc=$?
  case "$rc" in
    0) pass "no high/critical CVEs (brew vulns): ${formulae[*]}" ;;
    1) fail "brew vulns found high/critical CVE(s) in batch: ${formulae[*]} — full findings in scan output above"
       while IFS= read -r l; do [[ -n "$l" ]] && printf '        %s\n' "$l"; done <<<"$out" ;;
    *) warn "brew vulns scan error (rc=$rc): $(printf '%s' "$out" | head -1)" ;;
  esac
}

cve_formulae=()
for tok in "${new_tokens[@]}"; do
  [[ -n "$tok" ]] || continue
  k=$(kind_of "$tok")
  audit_abandonment "$k" "$tok"
  # CVE scan applies to formulae only (brew vulns is formula-source based).
  if [[ "$k" == formula ]] && ! is_tapped "$tok"; then cve_formulae+=("$tok"); fi
done
if [[ "${#cve_formulae[@]}" -gt 0 ]]; then audit_cve_brewvulns "${cve_formulae[@]}"; fi

summary_exit
