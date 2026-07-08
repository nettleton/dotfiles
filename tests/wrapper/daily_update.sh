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

RUN_LOG="$(mktemp -t daily-update-log)"
brewfile="$(mktemp -t daily-update-brewfile)"
trap 'rm -f "$RUN_LOG" "$brewfile"' EXIT

# GitHub token for safe-upgrade/install release-age checks (5000/hr vs 60/hr).
# Best-effort: if 1Password is locked, proceed — safe-* fails closed on limits.
if token="$(op read 'op://Family/nettleton-homebrew-install-token/token' 2>/dev/null)"; then
  export GH_TOKEN="$token"
fi

echo "==> [1/4] safe-upgrade --self"
brew safe-upgrade --self || echo "WARN: --self failed (continuing)"

echo "==> [2/4] safe-upgrade --yes --min-age $MIN_AGE (installed packages)"
brew safe-upgrade --yes --min-age "$MIN_AGE" 2>&1 | tee -a "$RUN_LOG"

echo "==> [3/4] reconcile declared set (retries previously-held installs)"
# Personal packages only on non-work machines — ask chezmoi (allowed here).
personal_flag="--personal"
if command -v chezmoi >/dev/null 2>&1; then
  [ "$(chezmoi data 2>/dev/null | jq -r '.personalpackages' 2>/dev/null)" = "false" ] \
    && personal_flag="--no-personal"
fi
bash "$REPO/tests/lib/render_brewfile.sh" "$personal_flag" >"$brewfile"
awk -F'"' '/^brew /{print $2}' "$brewfile" \
  | xargs brew safe-install --min-age "$MIN_AGE" 2>&1 | tee -a "$RUN_LOG"
awk -F'"' '/^cask /{print $2}' "$brewfile" \
  | xargs brew safe-install --cask --min-age "$MIN_AGE" 2>&1 | tee -a "$RUN_LOG"

echo "==> [4/4] staleness cap (held > ${STALENESS_CAP}d)"
# Currently-held set: every "Held (too fresh): a b c" line from steps 2-3.
now="$(date +%s)"
held_now="$(grep 'Held (too fresh):' "$RUN_LOG" | sed 's/.*Held (too fresh)://' \
  | tr ' ' '\n' | sed '/^$/d' | sort -u)"

# Update state: keep first-seen epoch for still-held; add new; drop resolved.
new_state="$(mktemp -t held-state)"
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

echo "==> daily update done"
