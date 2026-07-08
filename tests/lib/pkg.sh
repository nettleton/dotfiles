#!/usr/bin/env bash
# Package-data accessors + Homebrew JSON API fetcher, shared by the check
# scripts. Source AFTER common.sh. Reads $PACKAGES_YAML via yq (mikefarah v4).

# --- list accessors ---------------------------------------------------------
# Each emits one item per line (empty output if the key is absent).
pkg_brews()          { yq '.packages.brew.brews[]'          "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_casks()          { yq '.packages.brew.casks[]'          "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_personal_brews() { yq '.packages.brew.personal_brews[]' "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_personal_casks() { yq '.packages.brew.personal_casks[]' "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_tap_names()      { yq '.packages.brew.taps[].name'      "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_fisher()         { yq '.packages.fisher[]'              "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_fisher_darwin()  { yq '.packages.fisher_darwin[]'       "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_go()             { yq '.packages.go[]'                  "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_mas_ids()        { yq '.packages.mas.apps[].id'         "$PACKAGES_YAML" 2>/dev/null || true; }
pkg_mas_personal_ids(){ yq '.packages.mas.personal_apps[].id' "$PACKAGES_YAML" 2>/dev/null || true; }

# All brews (core + personal) / all casks, deduped — the full declared set.
pkg_all_brews() { { pkg_brews; pkg_personal_brews; } | sort -u; }
pkg_all_casks() { { pkg_casks; pkg_personal_casks; } | sort -u; }

# True if a package token is tapped (vendor/tap/name) rather than core.
is_tapped() { [[ "$1" == */* ]]; }

# tap prefix "vendor/tap" from a tapped token "vendor/tap/name"
tap_of() { printf '%s\n' "${1%/*}"; }

# --- Homebrew JSON API fetch + cache ---------------------------------------
# Cache lives OUTSIDE the repo so it never pollutes the source tree.
CACHE_DIR="${TEST_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi-dotfiles-tests}"
CACHE_TTL="${TEST_CACHE_TTL:-21600}" # 6h

# _cache_fresh <file> -> 0 if file exists and is younger than CACHE_TTL
_cache_fresh() {
  local f="$1"
  [[ -s "$f" ]] || return 1
  local now mtime
  now=$(date +%s)
  mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
  [[ $((now - mtime)) -lt "$CACHE_TTL" ]]
}

# brew_api_fetch <formula|cask> <name>
#   Fetches the Homebrew JSON (cached) and echoes the cache file path on stdout.
#   Returns: 0 = exists (HTTP 200), 1 = not found (404), 2 = network/other error.
brew_api_fetch() {
  local kind="$1" name="$2"
  local safe="${name//\//__}"
  local dir="$CACHE_DIR/$kind"
  local json="$dir/$safe.json" code="$dir/$safe.code"
  mkdir -p "$dir"
  if _cache_fresh "$json" && [[ -s "$code" ]]; then
    printf '%s\n' "$json"
    [[ "$(cat "$code")" == 200 ]] && return 0 || return 1
  fi
  local http
  http=$(curl -s -o "$json" -w '%{http_code}' \
    "https://formulae.brew.sh/api/$kind/$name.json" 2>/dev/null) || { printf '%s\n' "$json"; return 2; }
  printf '%s' "$http" >"$code"
  printf '%s\n' "$json"
  case "$http" in
    200) return 0 ;;
    404) return 1 ;;
    *)   return 2 ;;
  esac
}
