#!/usr/bin/env bash
# CI CVE scan (tier-b): chunked `brew vulns --cyclonedx` over a core-only
# Brewfile, merged into one SBOM. See TESTING.md §7.
#
# Why chunked: brew vulns sends each invocation's packages as ONE OSV query
# with a fixed read timeout — the full ~145-package set reliably times out
# (observed locally and on CI). Batches of ~10 are fast; one retry per batch
# for transient OSV flakiness, then a per-package fallback for the batch.
# Packages whose OSV history is too large even for a SINGLE-package query
# (e.g. vim) live in tests/cve_scan_skiplist.txt — a documented CI-only gap;
# safe-upgrade still CVE-checks them at every upgrade.
#
# Single CycloneDX pass: the SBOM embeds the vulnerability findings, so it is
# both the gate (exit code) and the Dependabot submission artifact. (A SARIF
# pass would double the OSV load for a nice-to-have; dropped.)
#
# Usage: ci_cve_scan.sh <brewfile> [outdir]     (writes <outdir>/sbom.cdx.json)
# Exit:  0 clean · 1 high/critical findings · 2 scan errors (coverage gap)
set -uo pipefail

brewfile="${1:?usage: ci_cve_scan.sh <brewfile> [outdir]}"
outdir="${2:-.}"
BATCH="${CVE_SCAN_BATCH:-10}"
SKIPLIST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cve_scan_skiplist.txt"
mkdir -p "$outdir"
work="$(mktemp -d -t ci-cve-scan.XXXXXX)"
trap 'rm -rf "$work"' EXIT

skiplisted() {
  [[ -f "$SKIPLIST" ]] || return 1
  sed 's/#.*//' "$SKIPLIST" | tr -d ' \t' | grep -qxF "$1"
}

names=()
skipped=""
while IFS= read -r n; do
  [[ -n "$n" ]] || continue
  if skiplisted "$n"; then skipped="$skipped$n "; else names+=("$n"); fi
done < <(awk -F'"' '/^(brew|cask) /{print $2}' "$brewfile")
total="${#names[@]}"
[[ "$total" -gt 0 ]] || { echo "no packages in $brewfile"; exit 2; }
echo "scanning $total packages in batches of $BATCH"
[[ -n "$skipped" ]] && echo "skiplisted (cve_scan_skiplist.txt, CI-only gap): $skipped"

findings=0
errors=0

# scan_once <outfile> <pkgs...> — one retry on scan error (rc>=2); deletes
# the output on final failure so the merge never sees partial/garbage JSON.
scan_once() {
  local out="$1"; shift
  local rc
  brew vulns --severity high --cyclonedx "$@" >"$out" 2>"$work/err"; rc=$?
  if [[ "$rc" -ge 2 ]]; then
    sleep 3
    brew vulns --severity high --cyclonedx "$@" >"$out" 2>"$work/err"; rc=$?
  fi
  [[ "$rc" -ge 2 ]] && rm -f "$out"
  return "$rc"
}

i=0
batch_no=0
while [[ "$i" -lt "$total" ]]; do
  batch=("${names[@]:i:BATCH}")
  batch_no=$((batch_no + 1))
  rc=0
  scan_once "$work/sbom.$batch_no" "${batch[@]}" || rc=$?
  if [[ "$rc" -eq 1 ]]; then
    findings=1
  elif [[ "$rc" -ge 2 ]]; then
    echo "  batch $batch_no error — falling back to per-package: ${batch[*]}"
    for p in "${batch[@]}"; do
      prc=0
      scan_once "$work/sbom.$batch_no-$p" "$p" || prc=$?
      if [[ "$prc" -eq 1 ]]; then
        findings=1
      elif [[ "$prc" -ge 2 ]]; then
        errors=$((errors + 1))
        echo "  SCAN ERROR after retries: $p — $(head -1 "$work/err" 2>/dev/null) (candidate for cve_scan_skiplist.txt if chronic)"
      fi
    done
  fi
  i=$((i + BATCH))
done

# Merge CycloneDX: first doc's envelope + concatenated components/vulns.
# Only files that parse as JSON (failed scans were deleted; belt-and-braces).
valid_json() { local f; for f in "$@"; do [[ -s "$f" ]] && jq empty "$f" 2>/dev/null && echo "$f"; done; }
sbom_files=()
while IFS= read -r f; do sbom_files+=("$f"); done < <(valid_json "$work"/sbom.*)
if [[ "${#sbom_files[@]}" -eq 0 ]]; then
  echo "no valid scan output produced"
  exit 2
fi
jq -s '. as $all
       | $all[0]
       | .components      = ($all | map(.components // [])      | add)
       | .vulnerabilities = ($all | map(.vulnerabilities // []) | add)' \
  "${sbom_files[@]}" > "$outdir/sbom.cdx.json"
echo "merged SBOM from ${#sbom_files[@]} scan(s): $(jq '.components | length' "$outdir/sbom.cdx.json") component(s), $(jq '.vulnerabilities | length' "$outdir/sbom.cdx.json") vulnerability record(s)"

echo "batches: $batch_no · findings: $findings · scan errors: $errors"
[[ "$errors" -gt 0 ]] && exit 2
[[ "$findings" -gt 0 ]] && exit 1
exit 0
