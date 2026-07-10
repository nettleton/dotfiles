#!/usr/bin/env bash
# A2 — lint rendered scripts. Renders every .chezmoiscripts template against
# the personal AND work profiles (union covers both sides of machine guards),
# plus raw shell sources (tests/, .githooks, non-template scripts), then:
#   bash scripts: bash -n always; shellcheck (severity=error) when installed
#   fish scripts: fish --no-execute when installed
# See TESTING.md §5 A2.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

FIXTURES_DIR="$TESTS_DIR/fixtures"
STUBBIN="$TESTS_DIR/stubbin"
have chezmoi || die "chezmoi is required for lint (renders templates)"
export PATH="$STUBBIN:$PATH"

workdir="$(mktemp -d -t chezmoi-lint.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

render() { # <fixture> <template> -> stdout
  chezmoi --config "$FIXTURES_DIR/$1.toml" --source "$REPO_ROOT" \
          --persistent-state "$workdir/$1-state.db" --cache "$workdir/$1-cache" \
          execute-template <"$REPO_ROOT/$2" 2>/dev/null
}

have shellcheck && SC=1 || SC=0
have fish && FISH=1 || FISH=0
[[ "$SC" -eq 1 ]] || note "shellcheck not installed — bash -n only (declared in packages.yaml)"
[[ "$FISH" -eq 1 ]] || note "fish not installed — skipping fish parse checks"

lint_file() { # <display-name> <path>
  local name="$1" path="$2" shebang
  shebang="$(head -1 "$path")"
  case "$shebang" in
    *fish*)
      if [[ "$FISH" -eq 1 ]]; then
        if fish --no-execute "$path" 2>"$workdir/err"; then
          pass "fish -n  $name"
        else
          fail "fish parse error in $name: $(head -1 "$workdir/err")"
        fi
      fi
      ;;
    *)
      if ! bash -n "$path" 2>"$workdir/err"; then
        fail "bash -n error in $name: $(head -1 "$workdir/err")"
      elif [[ "$SC" -eq 1 ]] && ! shellcheck -S error -s bash "$path" >"$workdir/sc" 2>&1; then
        fail "shellcheck error(s) in $name: $(grep -m1 'SC[0-9]' "$workdir/sc" || head -1 "$workdir/sc")"
      else
        pass "lint OK  $name"
      fi
      ;;
  esac
}

section "rendered script templates (personal + work profiles)"
for tmpl in "$REPO_ROOT"/.chezmoiscripts/*.tmpl; do
  base="$(basename "$tmpl")"
  for profile in personal work; do
    out="$workdir/$profile-$base"
    render "$profile" ".chezmoiscripts/$base" >"$out" || { fail "render failed: $base ($profile)"; continue; }
    # Machine-guarded scripts legitimately render empty on excluded profiles.
    [[ -n "$(tr -d '[:space:]' <"$out")" ]] || continue
    lint_file "$base [$profile]" "$out"
  done
done

section "raw shell sources"
while IFS= read -r f; do
  lint_file "$f" "$REPO_ROOT/$f"
done < <(cd "$REPO_ROOT" && git ls-files '.chezmoiscripts/*.sh' '.githooks/*' 'tests/lib/*.sh' 'tests/wrapper/*.sh' 'tests/run.sh' 'tests/stubbin/*')

summary_exit
