#!/usr/bin/env bash
# A4 — package existence. Network, no auth. See TESTING.md §5.
#
# Every declared brew/cask must still exist upstream (catches the #1 auto-update
# breakage: an upstream rename/removal that would otherwise reach the destructive
# prune). Core tokens are checked against the Homebrew JSON API; tapped tokens
# (vendor/tap/name) are validated for tap-linkage and confirmed via `brew info`
# when available. mas ids are checked against the iTunes lookup API.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"
require_packages_yaml
have curl || die "curl is required for existence checks"

section "package existence (upstream)"

declared_taps="$(pkg_tap_names | sort -u)"

# check_one <formula|cask> <name>
check_one() {
  local kind="$1" name="$2"
  if is_tapped "$name"; then
    # Tapped token: verify its tap is declared, then confirm via brew if present.
    local tap; tap="$(tap_of "$name")"
    if ! grep -qxF "$tap" <<<"$declared_taps"; then
      fail "$kind '$name' references undeclared tap '$tap'"
      return
    fi
    if ! have brew; then
      note "$kind $name (tapped; brew unavailable — existence deferred to Tier B)"
    elif ! brew tap 2>/dev/null | grep -qxF "$tap"; then
      # Tap declared but not added on this machine yet (e.g. a just-declared tool,
      # pre-apply). `brew info` can't see it — can't confirm, but not a failure.
      note "$kind $name (tap '$tap' not yet added locally — existence confirmed after apply / in CI)"
    elif brew info ${kind:+$([[ $kind == cask ]] && echo --cask)} "$name" >/dev/null 2>&1; then
      pass "$kind $name (tapped, confirmed via brew)"
    else
      fail "$kind '$name' not found in already-added tap '$tap' — typo or removed?"
    fi
    return
  fi
  # Core token: Homebrew JSON API.
  local rc; brew_api_fetch "$kind" "$name" >/dev/null; rc=$?
  case "$rc" in
    0) pass "$kind $name" ;;
    1) fail "$kind '$name' does not exist upstream (HTTP 404) — renamed or removed?" ;;
    2) warn "$kind '$name' could not be verified (network error)" ;;
  esac
}

while IFS= read -r b; do [[ -n "$b" ]] && check_one formula "$b"; done < <(pkg_all_brews)
while IFS= read -r c; do [[ -n "$c" ]] && check_one cask "$c"; done < <(pkg_all_casks)

# --- mas ids (iTunes lookup, batched) ---------------------------------------
# NOTE: the iTunes lookup API is advisory only — it does not reliably return
# some App Store apps (notably Apple's own iWork apps), so an unresolved id is a
# WARN, not a FAIL. Authoritative MAS verification is Tier C (`mas info <id>`).
section "Mac App Store ids (advisory — iTunes lookup)"

mas_ids=()
while IFS= read -r id; do [[ -n "$id" ]] && mas_ids+=("$id"); done < <({ pkg_mas_ids; pkg_mas_personal_ids; } | sort -u)

resolved="$(mktemp)"; trap 'rm -f "$resolved"' EXIT
i=0; n="${#mas_ids[@]}"
while [[ "$i" -lt "$n" ]]; do
  chunk=""
  for ((j=0; j<20 && i<n; j++, i++)); do chunk+="${mas_ids[$i]},"; done
  chunk="${chunk%,}"
  curl -s "https://itunes.apple.com/lookup?id=$chunk&country=us" \
    | jq -r '.results[].trackId // empty' 2>/dev/null >>"$resolved" || true
done

# Ids acknowledged as unresolvable (e.g. legacy ids after Apple re-released
# the app under a new id) — downgraded to a note. Inline comments allowed.
MAS_ALLOW="$TESTS_DIR/mas_allowlist.txt"
mas_allowlisted() {
  [[ -f "$MAS_ALLOW" ]] || return 1
  sed 's/#.*//' "$MAS_ALLOW" | tr -d ' \t' | grep -qxF "$1"
}

for id in "${mas_ids[@]}"; do
  if grep -qxF "$id" "$resolved"; then
    pass "mas id $id"
  elif mas_allowlisted "$id"; then
    note "mas id $id not in iTunes lookup — acknowledged (mas_allowlist)"
  else
    warn "mas id $id not returned by iTunes lookup (API is unreliable for some apps — verify with 'mas info $id')"
  fi
done

summary_exit
