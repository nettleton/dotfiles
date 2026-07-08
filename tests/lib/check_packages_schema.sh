#!/usr/bin/env bash
# A3 — packages.yaml schema + hygiene. Pure data, no network. See TESTING.md §5.
#
#   valid YAML · taps have a name · no dup within a list · no cross-list dup ·
#   mas entries have integer id + name · (optional) sorted-order warning.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/pkg.sh"
require_packages_yaml

section "packages.yaml schema & hygiene"

# --- valid YAML -------------------------------------------------------------
if yq -e '.' "$PACKAGES_YAML" >/dev/null 2>&1; then
  pass "valid YAML"
else
  fail "packages.yaml is not valid YAML"
  summary_exit; exit
fi

# --- taps: each has a name; url/trusted correctly typed ----------------------
tap_count=$(yq '.packages.brew.taps | length' "$PACKAGES_YAML")
missing_name=$(yq '[.packages.brew.taps[] | select(has("name") | not)] | length' "$PACKAGES_YAML")
if [[ "$missing_name" -eq 0 ]]; then
  pass "all $tap_count taps have a name"
else
  fail "$missing_name tap entry/entries missing 'name'"
fi
bad_trusted=$(yq '[.packages.brew.taps[] | select(has("trusted")) | select(.trusted | tag != "!!bool")] | length' "$PACKAGES_YAML")
[[ "$bad_trusted" -eq 0 ]] || fail "$bad_trusted tap(s) have a non-boolean 'trusted'"

# --- duplicates within each list --------------------------------------------
check_dupes_within() {
  local label="$1"; shift
  local dupes
  dupes=$("$@" | sort | uniq -d)
  if [[ -z "$dupes" ]]; then
    pass "no duplicates in $label"
  else
    fail "duplicate entries in $label: $(printf '%s ' $dupes)"
  fi
}
check_dupes_within "brews"          pkg_brews
check_dupes_within "casks"          pkg_casks
check_dupes_within "personal_brews" pkg_personal_brews
check_dupes_within "personal_casks" pkg_personal_casks
check_dupes_within "taps"           pkg_tap_names
check_dupes_within "fisher"         pkg_fisher
check_dupes_within "go"             pkg_go
check_dupes_within "mas.apps ids"   pkg_mas_ids

# --- cross-list duplicates (a package declared in both core and personal) ----
check_cross() {
  local label="$1" a_fn="$2" b_fn="$3"
  local both
  both=$(comm -12 <("$a_fn" | sort -u) <("$b_fn" | sort -u))
  if [[ -z "$both" ]]; then
    pass "no overlap between $label"
  else
    fail "declared in both $label: $(printf '%s ' $both)"
  fi
}
check_cross "brews & personal_brews" pkg_brews pkg_personal_brews
check_cross "casks & personal_casks" pkg_casks pkg_personal_casks
check_cross "mas.apps & personal_apps ids" pkg_mas_ids pkg_mas_personal_ids

# --- mas: integer id + name -------------------------------------------------
for key in apps personal_apps; do
  n=$(yq ".packages.mas.$key | length" "$PACKAGES_YAML" 2>/dev/null || echo 0)
  [[ "$n" -gt 0 ]] || continue
  bad_id=$(yq "[.packages.mas.$key[] | select(.id | tag != \"!!int\")] | length" "$PACKAGES_YAML")
  no_name=$(yq "[.packages.mas.$key[] | select(has(\"name\") | not)] | length" "$PACKAGES_YAML")
  [[ "$bad_id" -eq 0 ]]  && pass "mas.$key: all ids are integers" || fail "mas.$key: $bad_id non-integer id(s)"
  [[ "$no_name" -eq 0 ]] && pass "mas.$key: all entries have a name" || fail "mas.$key: $no_name entry/entries missing name"
done

# --- optional: sorted-order (warning only; installer sorts at render time) ---
check_sorted() {
  local label="$1"; shift
  if diff -q <("$@") <("$@" | sort -f) >/dev/null 2>&1; then
    note "$label is sorted"
  else
    warn "$label is not alphabetically sorted (cosmetic; aids diffs)"
  fi
}
check_sorted "brews"          pkg_brews
check_sorted "casks"          pkg_casks
check_sorted "personal_brews" pkg_personal_brews
check_sorted "personal_casks" pkg_personal_casks

summary_exit
