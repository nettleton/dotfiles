#!/usr/bin/env bash
# Render a Brewfile from packages.yaml, mirroring the logic in
# .chezmoiscripts/run_onchange_01_install-brew-packages.sh.tmpl. Used by the
# prune-guard and Brewfile tests so they don't need `chezmoi` (and thus can run
# inside the apply preflight). Emits the Brewfile on stdout.
#
# Usage: render_brewfile.sh [--personal|--no-personal]   (default: --personal)
#
# NOTE: this deliberately duplicates the installer's template logic. A Phase-3
# golden test should diff this against the real rendered script to catch drift.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"
require_packages_yaml

personal=1
case "${1:-}" in
  --no-personal) personal=0 ;;
  --personal|"") personal=1 ;;
  *) die "usage: render_brewfile.sh [--personal|--no-personal]" ;;
esac

# taps (name, optional url, optional trusted). Iterate by index — a TSV row with
# an empty middle field collapses under tab-IFS `read`, so query each field.
tap_count=$(yq '.packages.brew.taps | length' "$PACKAGES_YAML")
for ((k = 0; k < tap_count; k++)); do
  name=$(yq ".packages.brew.taps[$k].name" "$PACKAGES_YAML")
  url=$(yq ".packages.brew.taps[$k].url // \"\"" "$PACKAGES_YAML")
  trusted=$(yq ".packages.brew.taps[$k].trusted // false" "$PACKAGES_YAML")
  line="tap \"$name\""
  [[ -n "$url" ]] && line+=", \"$url\""
  [[ "$trusted" == "true" ]] && line+=", trusted: true"
  printf '%s\n' "$line"
done

pkg_brews | sort -f | uniq | while IFS= read -r b; do [[ -n "$b" ]] && printf 'brew "%s"\n' "$b"; done
if [[ "$personal" -eq 1 ]]; then
  pkg_personal_brews | sort -f | uniq | while IFS= read -r b; do [[ -n "$b" ]] && printf 'brew "%s"\n' "$b"; done
fi
pkg_casks | sort -f | uniq | while IFS= read -r c; do [[ -n "$c" ]] && printf 'cask "%s"\n' "$c"; done
if [[ "$personal" -eq 1 ]]; then
  pkg_personal_casks | sort -f | uniq | while IFS= read -r c; do [[ -n "$c" ]] && printf 'cask "%s"\n' "$c"; done
fi
