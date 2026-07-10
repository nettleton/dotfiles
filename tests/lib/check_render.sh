#!/usr/bin/env bash
# A1 — hermetic render matrix. Every template must render against every
# synthetic machine profile in tests/fixtures/, with 1Password faked by
# tests/stubbin/op. No Mac state or secrets needed. See TESTING.md §4-5.
#
#   1. Full-source render per profile: `apply --dry-run` into a throwaway
#      destination renders every applicable file/script template in one
#      chezmoi invocation (scripts are rendered, not executed; externals
#      excluded — no network).
#   2. Machine-guard spot checks: work-only / personal-only templates must
#      render empty on the profiles that exclude them.
#   3. Managed-set assertions: .chezmoiignore routing per profile.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FIXTURES_DIR="$TESTS_DIR/fixtures"
STUBBIN="$TESTS_DIR/stubbin"
have chezmoi || die "chezmoi is required for render checks"
[[ -d "$FIXTURES_DIR" ]] || die "fixtures not found at $FIXTURES_DIR"
export PATH="$STUBBIN:$PATH"

workdir="$(mktemp -d -t chezmoi-render.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

# cz <fixture> <args...> — chezmoi against a synthetic profile, isolated state.
cz() {
  local fixture="$1"; shift
  local dest="$workdir/$fixture-dest"
  mkdir -p "$dest"
  chezmoi --config "$FIXTURES_DIR/$fixture.toml" \
          --source "$REPO_ROOT" \
          --destination "$dest" \
          --persistent-state "$workdir/$fixture-state.db" \
          --cache "$workdir/$fixture-cache" \
          "$@"
}

# render <fixture> <template-path> — execute-template with the profile.
render() { cz "$1" execute-template <"$REPO_ROOT/$2"; }

section "full-source render per profile (apply --dry-run)"
for f in "$FIXTURES_DIR"/*.toml; do
  name="$(basename "$f" .toml)"
  if out="$(cz "$name" apply --dry-run --exclude externals 2>&1)"; then
    pass "profile $name: all applicable templates render"
  else
    fail "profile $name: render failure — $(printf '%s' "$out" | grep -m1 'chezmoi:' || printf '%s' "$out" | head -1)"
  fi
done

section "machine-guard spot checks"
if [[ "$(uname)" != "Darwin" ]]; then
  # All .chezmoiscripts are darwin-guarded and .chezmoi.os is not fakeable,
  # so on Linux they ALL render empty — the non-empty assertions below would
  # false-fail. The full-source renders above still cover file templates.
  note "non-Darwin host: script-guard spot checks skipped (.chezmoi.os guards)"
else
# assert_empty <fixture> <template> / assert_nonempty <fixture> <template>
assert_empty() {
  local n; n="$(render "$1" "$2" 2>/dev/null | tr -d '[:space:]' | wc -c | tr -d ' ')"
  [[ "$n" -eq 0 ]] && pass "$2 empty on $1" || fail "$2 rendered non-empty on $1 (guard broken?)"
}
assert_nonempty() {
  local n; n="$(render "$1" "$2" 2>/dev/null | tr -d '[:space:]' | wc -c | tr -d ' ')"
  [[ "$n" -gt 0 ]] && pass "$2 renders on $1" || fail "$2 rendered EMPTY on $1 (guard broken?)"
}
# work-only internal packages script
assert_nonempty work     .chezmoiscripts/run_onchange_03-03_install-internal-packages.sh.tmpl
assert_empty    personal .chezmoiscripts/run_onchange_03-03_install-internal-packages.sh.tmpl
assert_empty    wife     .chezmoiscripts/run_onchange_03-03_install-internal-packages.sh.tmpl
# non-work remote access (sshd + screen sharing)
assert_nonempty personal .chezmoiscripts/run_once_00-02_configure-remote-access.sh.tmpl
assert_empty    work     .chezmoiscripts/run_once_00-02_configure-remote-access.sh.tmpl
# brew-update agent loader: personal desktop only (trial)
assert_nonempty personal .chezmoiscripts/run_onchange_after_00_load-brew-update-agent.sh.tmpl
assert_empty    work     .chezmoiscripts/run_onchange_after_00_load-brew-update-agent.sh.tmpl
assert_empty    wife     .chezmoiscripts/run_onchange_after_00_load-brew-update-agent.sh.tmpl
# preflight runs everywhere (darwin)
assert_nonempty work     .chezmoiscripts/run_before_01_preflight.sh.tmpl
fi

section "managed-set routing (.chezmoiignore per profile)"
# assert_managed <fixture> <target> <yes|no>
assert_managed() {
  local listed
  listed="$(cz "$1" managed 2>/dev/null | grep -cxF "$2" || true)"
  if [[ "$3" == yes ]]; then
    [[ "$listed" -gt 0 ]] && pass "$1 manages $2" || fail "$1 does NOT manage $2 (expected managed)"
  else
    [[ "$listed" -eq 0 ]] && pass "$1 excludes $2" || fail "$1 manages $2 (expected ignored)"
  fi
}
assert_managed personal "Library/LaunchAgents/io.nettleton.brew-update.plist" yes
assert_managed work     "Library/LaunchAgents/io.nettleton.brew-update.plist" no
assert_managed wife     "Library/LaunchAgents/io.nettleton.brew-update.plist" no
assert_managed work     ".netrc" yes
assert_managed personal ".netrc" no
assert_managed personal ".config/swiftbar/solaredge.15m.py" yes
assert_managed work     ".config/swiftbar/solaredge.15m.py" no

summary_exit
