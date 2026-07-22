#!/usr/bin/env bash
# Daily package updater (TESTING.md §7) — the brew leg of the auto-update loop.
# Runs OUTSIDE chezmoi apply (launchd/cron/agent), so it MAY call chezmoi.
#
#   1. brew safe-upgrade --self            keep the gate itself current
#   2. brew safe-upgrade --yes --min-age 7 gated upgrades of installed packages
#   3. reconcile: safe-install the declared set — picks up packages that were
#      HELD at install time once they age past 7 days. safe-upgrade cannot do
#      this: it only sees installed packages; a held package is absent, not
#      outdated. Installed packages skip fast (~0.8s, no network).
#   4. staleness cap: packages held on EVERY run for > STALENESS_CAP days are
#      starving (release cadence faster than min-age — the latest version is
#      never old enough). Default: report them and the exact escape command.
#      With --upgrade-capped (or UPGRADE_CAPPED=1), upgrade/install them with
#      --min-age 0 — a deliberate, bounded policy exception (still CVE/SHA
#      checked). chezmoi apply NEVER forces; only this updater can, opt-in.
#   5. sudo summary: pkg-installer casks (mactex, tailscale-app, …) run
#      `sudo installer`, which fails without a TTY when this job runs
#      unattended. Detect those failures, list the casks that need an
#      interactive `mise run update` (Touch ID sudo), and post a macOS
#      notification so stale pkg casks aren't discovered by accident.
#
# Then an authoritative "package changes this run" summary: a real
# Cellar/Caskroom version diff (before vs after), because brew's own per-step
# "Upgraded N" line over-reports — it counts dependents it planned to upgrade
# even when a held/pinned dependency blocks the actual pour.
#
# Usage: daily_update.sh [--upgrade-capped]
# Env:   MIN_AGE (7) · STALENESS_CAP days (21) · UPGRADE_CAPPED=1
#
# TODO(phase 4): mise up, fisher update, go install, mas upgrade, version
# capture, and the chezmoi-calling checks (C4-C8).

set -uo pipefail
REPO="${CHEZMOI_REPO:-$HOME/.local/share/chezmoi}"
MIN_AGE="${MIN_AGE:-7}"
STALENESS_CAP="${STALENESS_CAP:-21}"
upgrade_capped=0
[[ "${1:-}" == "--upgrade-capped" || -n "${UPGRADE_CAPPED:-}" ]] && upgrade_capped=1

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi-dotfiles-tests"
HELD_STATE="$STATE_DIR/held_since.txt"   # lines: <pkg>|<epoch first seen held>
mkdir -p "$STATE_DIR"
touch "$HELD_STATE"

RUN_LOG="$(mktemp -t daily-update-log.XXXXXX)"
brewfile="$(mktemp -t daily-update-brewfile.XXXXXX)"
before_versions="$(mktemp -t daily-update-before.XXXXXX)"
after_versions="$(mktemp -t daily-update-after.XXXXXX)"
trap 'rm -f "$RUN_LOG" "$brewfile" "$before_versions" "$after_versions"' EXIT

# Authoritative "what actually changed" reporting. brew's own per-step
# "Upgraded N packages" line counts dependents it PLANNED to upgrade even when a
# pinned/held dependency then blocks the pour, so it over-reports (e.g. gstreamer
# is listed as upgraded but never actually lands while ca-certificates is held).
# We instead diff the real Cellar/Caskroom versions before vs after the run, so
# the summary reflects what landed on disk, not what brew intended.
TAB="$(printf '\t')"
snapshot_versions() { # -> sorted "type|name<TAB>ver[,ver...]" (formulae + casks)
  { brew list --versions --formula 2>/dev/null | sed 's/^/formula /'
    brew list --versions --cask    2>/dev/null | sed 's/^/cask /'; } \
  | awk '{ t=$1; n=$2; v=""; for (i=3;i<=NF;i++) v=v (i>3?",":"") $i;
           print t"|"n"\t"v }' \
  | LC_ALL=C sort -t"$TAB" -k1,1
}
report_version_changes() { # $1=before-file $2=after-file
  local key bv av changed=0 type name
  while IFS="$TAB" read -r key bv av; do
    [[ "$bv" == "$av" ]] && continue
    changed=1; type="${key%%|*}"; name="${key#*|}"
    if   [[ "$bv" == "__NONE__" ]]; then printf '  installed  %-7s %s %s\n'      "$type" "$name" "$av"
    elif [[ "$av" == "__NONE__" ]]; then printf '  removed    %-7s %s %s\n'      "$type" "$name" "$bv"
    else                                 printf '  upgraded   %-7s %s %s -> %s\n' "$type" "$name" "$bv" "$av"
    fi
  done < <(LC_ALL=C join -t"$TAB" -a1 -a2 -e '__NONE__' -o '0,1.2,2.2' "$1" "$2")
  [[ "$changed" -eq 0 ]] && echo "  (no installed versions changed this run)"
}

# GitHub token for safe-upgrade/install release-age checks (5000/hr vs 60/hr):
# deliberately NOT fetched via `op read` — with 1Password app integration any
# op call pops a GUI auth prompt, which an unattended launchd job must never
# do. safe-upgrade's own fallback chain (GH_TOKEN -> GITHUB_TOKEN -> `gh auth
# token`) picks up the gh CLI login (02-06_configure-git-auth) prompt-free.
# If gh is unauthenticated it degrades to 60/hr, plenty for a daily
# outdated-set scan; safe-* fails closed if the limit is ever hit.

echo "==> daily update starting $(date '+%Y-%m-%d %H:%M:%S')"
snapshot_versions > "$before_versions"

echo "==> [1/5] safe-upgrade --self"
brew safe-upgrade --self || echo "WARN: --self failed (continuing)"

echo "==> [2/5] safe-upgrade --yes --min-age $MIN_AGE (installed packages)"
brew safe-upgrade --yes --min-age "$MIN_AGE" 2>&1 | tee -a "$RUN_LOG"

echo "==> [3/5] reconcile declared set (retries previously-held installs)"
# Personal packages only on non-work machines — ask chezmoi (allowed here).
personal_flag="--personal"
if command -v chezmoi >/dev/null 2>&1; then
  [ "$(chezmoi data 2>/dev/null | jq -r '.personalpackages' 2>/dev/null)" = "false" ] \
    && personal_flag="--no-personal"
fi
bash "$REPO/tests/lib/render_brewfile.sh" "$personal_flag" >"$brewfile"

# Compute MISSING = declared − installed here (two fast `brew list` calls,
# basename-matched for tapped tokens) instead of handing safe-install the
# whole declared set: it spawns a `brew info` ruby process per package just
# to conclude "already installed", which costs ~50 min for ~150 packages at
# launchd Background QoS. Held packages are missing, so the daily retry
# behavior is preserved; typically nothing is missing and both calls skip.
missing_of() { # <declared-names> <installed-names> -> declared-not-installed,
               # as FULL declared tokens (tapped names must keep vendor/tap/).
  local declared="$1" installed="$2" m
  comm -23 <(printf '%s\n' "$declared" | sed 's|.*/||' | sort -u) \
           <(printf '%s\n' "$installed" | sed 's|.*/||' | sort -u) \
    | while IFS= read -r m; do
        [[ -n "$m" ]] && printf '%s\n' "$declared" | grep -E "(^|/)${m}$" | head -1
      done
}
installed_formulae="$(brew list --formula -1 2>/dev/null || true)"
installed_casks="$(brew list --cask -1 2>/dev/null || true)"
missing_formulae="$(missing_of "$(awk -F'"' '/^brew /{print $2}' "$brewfile")" "$installed_formulae")"
missing_casks="$(missing_of "$(awk -F'"' '/^cask /{print $2}' "$brewfile")" "$installed_casks")"

if [[ -n "$missing_formulae" ]]; then
  # shellcheck disable=SC2086
  brew safe-install --min-age "$MIN_AGE" $missing_formulae 2>&1 | tee -a "$RUN_LOG"
else
  echo "all declared formulae installed — nothing to reconcile"
fi
if [[ -n "$missing_casks" ]]; then
  # shellcheck disable=SC2086
  brew safe-install --cask --min-age "$MIN_AGE" $missing_casks 2>&1 | tee -a "$RUN_LOG"
else
  echo "all declared casks installed — nothing to reconcile"
fi

echo "==> [4/5] staleness cap (held > ${STALENESS_CAP}d)"
# Currently-held set: every "Held (too fresh): a b c" line from steps 2-3.
now="$(date +%s)"
held_now="$(grep 'Held (too fresh):' "$RUN_LOG" | sed 's/.*Held (too fresh)://' \
  | tr ' ' '\n' | sed '/^$/d' | sort -u)"

# Update state: keep first-seen epoch for still-held; add new; drop resolved.
new_state="$(mktemp -t held-state.XXXXXX)"
while IFS= read -r pkg; do
  [[ -n "$pkg" ]] || continue
  since="$(grep -m1 "^$pkg|" "$HELD_STATE" | cut -d'|' -f2 || true)"
  printf '%s|%s\n' "$pkg" "${since:-$now}" >>"$new_state"
done <<<"$held_now"
mv "$new_state" "$HELD_STATE"

# Capped = held continuously for more than STALENESS_CAP days.
capped=""
while IFS='|' read -r pkg since; do
  [[ -n "$pkg" ]] || continue
  days=$(( (now - since) / 86400 ))
  [[ "$days" -gt "$STALENESS_CAP" ]] && capped="$capped$pkg"$'\n'
done <"$HELD_STATE"
capped="$(printf '%s' "$capped" | sed '/^$/d')"

if [[ -z "$capped" ]]; then
  echo "no packages capped ($(printf '%s\n' "$held_now" | sed '/^$/d' | wc -l | tr -d ' ') currently held, all within ${STALENESS_CAP}d)"
elif [[ "$upgrade_capped" -eq 0 ]]; then
  echo "CAPPED (held > ${STALENESS_CAP}d — release cadence outpaces min-age; NOT forcing):"
  while IFS= read -r p; do printf '  - %s\n' "$p"; done <<<"$capped"
  echo "force through the gate (still CVE/SHA checked) with:"
  echo "  $0 --upgrade-capped        # or per package:"
  while IFS= read -r p; do printf '  brew safe-upgrade --yes --min-age 0 %s\n' "$p"; done <<<"$capped"
else
  echo "CAPPED — upgrading with --min-age 0 (--upgrade-capped set; CVE/SHA checks still apply):"
  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if brew list "$p" >/dev/null 2>&1 || brew list --cask "$p" >/dev/null 2>&1; then
      brew safe-upgrade --yes --min-age 0 "$p" || echo "WARN: capped upgrade of $p failed"
    elif grep -q "^cask \"\(.*/\)\?$p\"" "$brewfile"; then
      brew safe-install --cask --min-age 0 "$p" || echo "WARN: capped install of $p failed"
    elif grep -q "^brew \"\(.*/\)\?$p\"" "$brewfile"; then
      brew safe-install --min-age 0 "$p" || echo "WARN: capped install of $p failed"
    else
      echo "WARN: capped '$p' neither installed nor declared — skipping"
    fi
  done <<<"$capped"
fi

echo "==> [5/5] sudo-required casks (pkg installers can't sudo unattended)"
# Unattended sudo fails with a recognizable message; attribute it to the
# outdated pkg-installer casks (minus any merely age-held ones) and surface.
sudo_hits="$(grep -cE 'a terminal is required to read the password|no tty present and no askpass' "$RUN_LOG" || true)"
if [[ "${sudo_hits:-0}" -eq 0 ]]; then
  echo "no sudo failures detected"
else
  outdated_casks="$(brew outdated --cask --quiet 2>/dev/null | sed 's|.*/||' || true)"
  pkg_casks=""
  if [[ -n "$outdated_casks" ]]; then
    # shellcheck disable=SC2086  # word-splitting the cask names is intended
    pkg_casks="$(brew info --json=v2 --cask $outdated_casks 2>/dev/null \
      | jq -r '.casks[] | select(.artifacts[]? | has("pkg") or has("installer")) | .token' 2>/dev/null \
      | sort -u || true)"
  fi
  needs_interactive=""
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    grep -qxF "$c" <<<"$held_now" || needs_interactive="$needs_interactive$c"$'\n'
  done <<<"$pkg_casks"
  needs_interactive="$(printf '%s' "$needs_interactive" | sed '/^$/d')"
  if [[ -n "$needs_interactive" ]]; then
    echo "NEEDS INTERACTIVE RUN — $sudo_hits sudo failure(s); these pkg casks need a terminal (Touch ID sudo):"
    while IFS= read -r c; do printf '  - %s\n' "$c"; done <<<"$needs_interactive"
    echo "run in a terminal:  mise run update"
    if command -v osascript >/dev/null 2>&1; then
      msg="Needs interactive 'mise run update' (sudo): $(printf '%s ' $needs_interactive)"
      osascript -e "display notification \"$msg\" with title \"brew daily update\"" 2>/dev/null || true
    fi
  else
    echo "sudo failure(s) detected ($sudo_hits) but no outdated pkg casks remain — inspect the run output above"
  fi
fi

echo "==> package changes this run (authoritative — actual Cellar/Caskroom diff):"
snapshot_versions > "$after_versions"
report_version_changes "$before_versions" "$after_versions"

echo "==> daily update done $(date '+%Y-%m-%d %H:%M:%S') (${SECONDS}s elapsed)"
