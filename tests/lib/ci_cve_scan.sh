#!/usr/bin/env bash
# CI CVE scan (tier-b): chunked `brew vulns --severity high --json` over a
# core-only Brewfile. Gate only — the exit code decides pass/fail; the merged
# findings JSON is an informational artifact. See TESTING.md §7.
#
# Why chunked: brew vulns sends each invocation's packages as ONE OSV query
# with a fixed read timeout — the full ~145-package set reliably times out
# (observed locally and on CI). Batches of ~10 are fast; one retry per batch
# for transient OSV flakiness, then a per-package fallback for the batch.
# Packages whose OSV history is too large even for a SINGLE-package query
# (e.g. vim) live in tests/cve_scan_skiplist.txt — a documented CI-only gap;
# safe-upgrade still CVE-checks them at every upgrade.
#
# No SBOM: `brew vulns` dropped --cyclonedx when it merged into brew core, and
# --json emits a findings list (vulnerable packages only), not a CycloneDX
# component inventory — so the old dependency-graph / Dependabot submission
# can't be fed from here anymore. This gate is the primary control; the daily
# safe-upgrade gate (§7) is the continuous one.
#
# Triaged findings can be suppressed from the gate via tests/cve_accept.txt
# ("<formula>  <OSV-ID>  # reason [(expires YYYY-MM-DD)]"); a suppressed finding
# is still printed and kept in the artifact. Fail-closed on drift, like the rest
# of the repo: an accept whose formula scans clean but no longer reports the ID
# (STALE — resolved upstream) or whose expiry has passed (EXPIRED) re-fails the
# build. A formula that couldn't be scanned this run (skiplisted / scan error)
# is never judged stale — absence there is a coverage gap, not a fix.
#
# Usage: ci_cve_scan.sh <brewfile> [outdir]   (writes <outdir>/cve-findings.json)
# Exit:  0 clean (or every finding accepted) · 1 gated finding / stale / expired
#        accept · 2 scan errors (coverage gap)
set -uo pipefail

brewfile="${1:?usage: ci_cve_scan.sh <brewfile> [outdir]}"
outdir="${2:-.}"
BATCH="${CVE_SCAN_BATCH:-10}"
SKIPLIST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cve_scan_skiplist.txt"
ACCEPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cve_accept.txt"
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

errors=0

# scan_once <outfile> <pkgs...> — one retry on scan error (rc>=2); deletes
# the output on final failure so the merge never sees partial/garbage JSON.
# brew vulns exit codes: 0 clean · 1 open high/critical vuln(s) · >=2 error.
scan_once() {
  local out="$1"; shift
  local rc
  brew vulns --severity high --json "$@" >"$out" 2>"$work/err"; rc=$?
  if [[ "$rc" -ge 2 ]]; then
    sleep 3
    brew vulns --severity high --json "$@" >"$out" 2>"$work/err"; rc=$?
  fi
  [[ "$rc" -ge 2 ]] && rm -f "$out"
  return "$rc"
}

i=0
batch_no=0
: > "$work/scanned_ok"   # formulae scanned authoritatively (rc 0/1) — the only
                         # ones an accept can be judged STALE against.
while [[ "$i" -lt "$total" ]]; do
  batch=("${names[@]:i:BATCH}")
  batch_no=$((batch_no + 1))
  rc=0
  scan_once "$work/out.$batch_no" "${batch[@]}" || rc=$?
  if [[ "$rc" -le 1 ]]; then
    printf '%s\n' "${batch[@]}" >> "$work/scanned_ok"
  else
    echo "  batch $batch_no error — falling back to per-package: ${batch[*]}"
    for p in "${batch[@]}"; do
      prc=0
      scan_once "$work/out.$batch_no-$p" "$p" || prc=$?
      if [[ "$prc" -le 1 ]]; then
        printf '%s\n' "$p" >> "$work/scanned_ok"
      else
        errors=$((errors + 1))
        echo "  SCAN ERROR after retries: $p — $(head -1 "$work/err" 2>/dev/null) (candidate for cve_scan_skiplist.txt if chronic)"
      fi
    done
  fi
  i=$((i + BATCH))
done

# Merge findings arrays into one informational artifact (the gate is the exit
# code, not this file). Only files that parse as JSON (failed scans were
# deleted; belt-and-braces). `brew vulns --json` emits [] for a clean batch.
valid_json() { local f; for f in "$@"; do [[ -s "$f" ]] && jq empty "$f" 2>/dev/null && echo "$f"; done; }
json_files=()
while IFS= read -r f; do json_files+=("$f"); done < <(valid_json "$work"/out.*)
if [[ "${#json_files[@]}" -eq 0 ]]; then
  echo "no valid scan output produced"
  exit 2
fi
jq -s 'add // []' "${json_files[@]}" > "$outdir/cve-findings.json"
vuln_pkgs="$(jq 'length' "$outdir/cve-findings.json")"
echo "merged findings from ${#json_files[@]} scan(s): $vuln_pkgs package(s) with high/critical vulnerabilities"

# Surface every finding in the log — the gate otherwise only prints a count, so
# CI shows THAT something is vulnerable but not WHAT. Full records (incl.
# accepted ones) are also in cve-findings.json (uploaded as an artifact).
if [[ "$vuln_pkgs" -gt 0 ]]; then
  echo ""
  echo "High/critical findings (formula @ version — open CVEs):"
  jq -r '.[]
    | "  \(.formula) \(.version)",
      ( (.vulnerabilities // [])[]
        | "      \(.id)  [\(.severity)]"
          + (if .summary then "  " + .summary else "" end)
          + (if ((.fixed_versions // []) | length) > 0
             then "  (fixed in: " + (.fixed_versions | join(", ")) + ")" else "" end) )' \
    "$outdir/cve-findings.json"
fi

# ---- Apply triaged acceptances (tests/cve_accept.txt) --------------------
today="$(date +%F)"
accepts="$work/accepts.tsv"   # formula \t id \t expiry \t reason
: > "$accepts"
if [[ -f "$ACCEPT" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    af="$(awk '{print $1}' <<<"$line")"; aid="$(awk '{print $2}' <<<"$line")"
    [[ -n "$af" && -n "$aid" ]] || { echo "WARN: malformed cve_accept.txt line: $line" >&2; continue; }
    reason="${line#*#}"; [[ "$reason" == "$line" ]] && reason=""
    reason="${reason#"${reason%%[![:space:]]*}"}"   # ltrim
    expiry=""
    [[ "$reason" =~ \(expires[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2})\) ]] && expiry="${BASH_REMATCH[1]}"
    printf '%s\t%s\t%s\t%s\n' "$af" "$aid" "$expiry" "$reason" >> "$accepts"
  done < "$ACCEPT"
fi

# Open (formula, id) findings from the merged artifact.
open_pairs="$work/open.tsv"
jq -r '.[] | .formula as $f | (.vulnerabilities // [])[] | "\($f)\t\(.id)"' \
  "$outdir/cve-findings.json" | sort -u > "$open_pairs"

# Classify each open finding: suppressed (live accept) vs gated (fails).
gated="$work/gated.tsv"; suppressed="$work/suppressed.tsv"
: > "$gated"; : > "$suppressed"
while IFS=$'\t' read -r f id; do
  [[ -n "$f" ]] || continue
  m="$(awk -F'\t' -v f="$f" -v id="$id" '$1==f && $2==id{print $3"\t"$4; exit}' "$accepts")"
  if [[ -z "$m" ]]; then
    printf '%s\t%s\t\n' "$f" "$id" >> "$gated"
  else
    exp="${m%%$'\t'*}"; reason="${m#*$'\t'}"
    if [[ -n "$exp" && "$exp" < "$today" ]]; then
      printf '%s\t%s\taccept EXPIRED %s — re-review\n' "$f" "$id" "$exp" >> "$gated"
    else
      printf '%s\t%s\t%s\n' "$f" "$id" "${reason:-accepted}" >> "$suppressed"
    fi
  fi
done < "$open_pairs"

# STALE accepts: formula scanned authoritatively but no longer reports the id.
stale="$work/stale.tsv"; : > "$stale"
while IFS=$'\t' read -r af aid exp reason; do
  [[ -n "$af" ]] || continue
  grep -qxF "$af" "$work/scanned_ok" || continue   # not authoritative → not stale
  awk -F'\t' -v f="$af" -v id="$aid" '$1==f && $2==id{h=1} END{exit !h}' "$open_pairs" && continue
  printf '%s\t%s\n' "$af" "$aid" >> "$stale"
done < "$accepts"

sup_n=$(wc -l < "$suppressed" | tr -d '[:space:]')
gate_n=$(wc -l < "$gated"      | tr -d '[:space:]')
stale_n=$(wc -l < "$stale"     | tr -d '[:space:]')

if [[ "$sup_n" -gt 0 ]]; then
  echo ""
  echo "accepted — suppressed via tests/cve_accept.txt (shown above, kept in artifact):"
  while IFS=$'\t' read -r f id reason; do echo "  $f $id — ${reason:-accepted}"; done < "$suppressed"
fi
if [[ "$stale_n" -gt 0 ]]; then
  echo ""
  echo "STALE acceptances — no longer flagged (resolved upstream). DELETE from tests/cve_accept.txt:"
  while IFS=$'\t' read -r f id; do echo "  $f  $id"; done < "$stale"
fi
if [[ "$gate_n" -gt 0 ]]; then
  echo ""
  echo "GATED — high/critical findings with no accepted exception:"
  while IFS=$'\t' read -r f id note; do echo "  $f $id${note:+  — $note}"; done < "$gated"
fi

echo ""
echo "batches: $batch_no · scan errors: $errors · gated: $gate_n · suppressed: $sup_n · stale: $stale_n"
[[ "$errors" -gt 0 ]] && exit 2
{ [[ "$gate_n" -gt 0 ]] || [[ "$stale_n" -gt 0 ]]; } && exit 1
exit 0
