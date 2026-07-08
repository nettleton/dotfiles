#!/usr/bin/env bash
# B2 — prune-guard. THE critical safety test. See TESTING.md §5.
#
# The installer runs `brew bundle cleanup --brews --casks --force`, which
# uninstalls anything not declared in packages.yaml. This guard renders the same
# Brewfile and computes what cleanup WOULD remove (dry-run, no --force). Any
# proposed removal not on tests/prune_allowlist.txt is a FAILURE — under
# auto-update, a typo or upstream rename must never silently trigger a mass
# uninstall.
#
# Usage: prune_guard.sh [--brewfile PATH] [--no-personal]
#   --brewfile  use a pre-rendered Brewfile (the preflight passes chezmoi's render)
#   default     render the superset (personal=on) so declared-but-uninstalled
#               packages never look like removals

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"

brewfile=""
personal_flag="--personal"
max_allowed=0   # fail if MORE than this many packages would be uninstalled
while [[ $# -gt 0 ]]; do
  case "$1" in
    --brewfile) brewfile="$2"; shift 2 ;;
    --no-personal) personal_flag="--no-personal"; shift ;;
    --max) max_allowed="$2"; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done

section "prune-guard (brew bundle cleanup dry-run)"

if ! have brew; then
  note "brew not available — prune-guard is macOS/Tier-B only; skipping"
  summary_exit; exit
fi

cleanup=""
if [[ -z "$brewfile" ]]; then
  brewfile="$(mktemp -t chezmoi-brewfile.XXXXXX)"
  trap 'rm -f "$brewfile"' EXIT
  bash "$LIB_DIR/render_brewfile.sh" "$personal_flag" >"$brewfile"
fi
[[ -s "$brewfile" ]] || die "rendered Brewfile is empty ($brewfile)"

# Dry-run cleanup (no --force). `brew bundle cleanup` emits TWO kinds of output:
#   1. package uninstalls  — under "Would uninstall formulae:/casks:" headers
#   2. cache/old-version gc — under "Would `brew cleanup`:" as "Would remove: …"
# The guard cares ONLY about (1). Scope parsing to the uninstall block(s) so the
# benign cache-gc lines are never misread as package removals.
out="$(brew bundle cleanup --brews --casks --file="$brewfile" 2>&1 || true)"
removals="$(printf '%s\n' "$out" | awk '
  /^Would uninstall/            { grab=1; next }
  /^Would `brew cleanup`/       { grab=0 }
  /^Would remove/              { grab=0 }
  /^Run /                       { grab=0 }
  /^Warning/                    { grab=0 }
  /^==>/                        { grab=0 }
  grab==1 && NF>0 { gsub(/,/," "); for (i=1;i<=NF;i++) print $i }
' | sort -u)"

# Allowlist of intentionally-permitted removals (one token per line, # comments).
allow="$TESTS_DIR/prune_allowlist.txt"
if [[ -f "$allow" ]]; then
  removals="$(comm -23 <(printf '%s\n' "$removals" | sed '/^$/d') \
                       <(grep -vE '^\s*(#|$)' "$allow" | sort -u))"
fi

# --- excuse intentional removals (recently declared in packages.yaml) --------
# Threat model: the prune must never mass-uninstall because of a typo, an
# upstream rename, or a template bug. But a removal whose package appeared in a
# RECENT COMMITTED version of packages.yaml and is absent from the current one
# is a deliberate edit — WARN, don't fail. Two escape valves keep the
# catastrophes detectable:
#   - orphaned dependencies of excused packages are excused too (removing a
#     declared package legitimately drags out deps that were never declared);
#   - more than PRUNE_EXCUSED_MAX excused removals at once looks like a bad
#     merge that dropped a block of declarations → still FAIL.
HISTORY_DEPTH="${PRUNE_HISTORY_DEPTH:-5}"
EXCUSED_MAX="${PRUNE_EXCUSED_MAX:-10}"

# Basenamed declared brews+casks at a given rev (cleanup output uses short
# names, so tapped tokens like vendor/tap/name are compared by basename).
declared_at() {
  # `|| true` rescues pipefail when a rev predates packages.yaml.
  git -C "$REPO_ROOT" show "$1:.chezmoidata/packages.yaml" 2>/dev/null \
    | yq '.packages.brew.brews[], .packages.brew.personal_brews[], .packages.brew.casks[], .packages.brew.personal_casks[]' 2>/dev/null \
    | sed 's|.*/||' | sort -u || true
}

recent_declared=""
if git -C "$REPO_ROOT" rev-parse >/dev/null 2>&1; then
  for rev in $(git -C "$REPO_ROOT" log -n "$HISTORY_DEPTH" --format=%H -- .chezmoidata/packages.yaml 2>/dev/null); do
    recent_declared="$recent_declared
$(declared_at "$rev")"
  done
fi
recent_declared="$(printf '%s\n' "$recent_declared" | sed '/^$/d' | sort -u)"
current_declared="$({ pkg_all_brews; pkg_all_casks; } | sed 's|.*/||' | sort -u)"

excused=""
unexcused=""
while IFS= read -r r; do
  [[ -n "$r" ]] || continue
  if ! grep -qxF "$r" <<<"$current_declared" && grep -qxF "$r" <<<"$recent_declared"; then
    excused="$excused$r"$'\n'
  else
    unexcused="$unexcused$r"$'\n'
  fi
done <<<"$removals"

# Second pass: excuse orphaned dependencies of excused packages. Per-name
# `brew deps` (casks in the excused set just error → contribute nothing).
if [[ -n "$(printf '%s' "$excused" | tr -d '[:space:]')" && -n "$(printf '%s' "$unexcused" | tr -d '[:space:]')" ]]; then
  dep_union="$(while IFS= read -r e; do
    # || true: casks in the excused set make `brew deps --formula` error —
    # they contribute no deps, and errexit must not kill the subshell.
    [[ -z "$e" ]] || brew deps --formula "$e" 2>/dev/null || true
  done <<<"$excused" | sort -u)"
  still=""
  while IFS= read -r r; do
    [[ -n "$r" ]] || continue
    if grep -qxF "$r" <<<"$dep_union"; then
      excused="$excused$r"$'\n'
    else
      still="$still$r"$'\n'
    fi
  done <<<"$unexcused"
  unexcused="$still"
fi

excused_count=0
[[ -n "$(printf '%s' "$excused" | tr -d '[:space:]')" ]] && excused_count=$(printf '%s' "$excused" | sed '/^$/d' | wc -l | tr -d ' ')
unexcused_count=0
[[ -n "$(printf '%s' "$unexcused" | tr -d '[:space:]')" ]] && unexcused_count=$(printf '%s' "$unexcused" | sed '/^$/d' | wc -l | tr -d ' ')
excused_list="$(printf '%s' "$excused" | sed '/^$/d' | tr '\n' ' ' | sed 's/ $//')"
unexcused_list="$(printf '%s' "$unexcused" | sed '/^$/d' | tr '\n' ' ' | sed 's/ $//')"

# --- verdicts -----------------------------------------------------------------
if [[ "$excused_count" -gt "$EXCUSED_MAX" ]]; then
  fail "prune would uninstall $excused_count recently-declared package(s) (> PRUNE_EXCUSED_MAX=$EXCUSED_MAX — bad merge that dropped declarations?): $excused_list"
elif [[ "$excused_count" -gt 0 ]]; then
  warn "prune will uninstall $excused_count package(s) recently removed from packages.yaml (intentional): $excused_list"
fi

if [[ "$unexcused_count" -eq 0 && "$excused_count" -eq 0 ]]; then
  pass "no packages would be pruned (Brewfile matches installed state, or all removals allowlisted)"
elif [[ "$unexcused_count" -eq 0 ]]; then
  pass "no unexplained removals (all pending removals were recently declared)"
elif [[ "$unexcused_count" -le "$max_allowed" ]]; then
  warn "prune would uninstall $unexcused_count never-declared package(s) (<= --max $max_allowed; not failing): $unexcused_list"
else
  fail "prune would UNINSTALL $unexcused_count package(s) never declared in the last $HISTORY_DEPTH packages.yaml revisions (> --max $max_allowed): $unexcused_list — typo/upstream rename, or ad-hoc install to adopt into packages.yaml (or prune_allowlist.txt)"
fi

summary_exit
