#!/usr/bin/env bash
# Self-heal the ONE safe kind of CVE-gate drift: accepts whose finding was
# resolved upstream (STALE). Deletes the matching lines from a cve_accept.txt
# given the scan's stale list (ci_cve_scan.sh writes cve-stale.tsv).
#
# Deliberately stale-ONLY. NEW gated findings and EXPIRED accepts are left
# untouched — those need human triage, and the gate stays fail-closed on them
# by design (see tests/cve_accept.txt and tests/lib/ci_cve_scan.sh).
#
# Section-aware: tests/cve_accept.txt groups accepts under "# --- name ---"
# comment headers. When the last accept under a header is removed, its whole
# comment block goes too; a header that still covers a surviving accept stays.
# The preamble and any free-standing comments are never touched.
#
# Usage: cve_reconcile.sh <cve_accept.txt> <cve-stale.tsv>
# Exit:  0 success (whether or not it changed anything — the caller diffs the
#          file to decide what to do); 2 bad arguments.
set -euo pipefail

accept="${1:?usage: cve_reconcile.sh <cve_accept.txt> <cve-stale.tsv>}"
stale="${2:?usage: cve_reconcile.sh <cve_accept.txt> <cve-stale.tsv>}"
[[ -f "$accept" ]] || { echo "no such file: $accept" >&2; exit 2; }
[[ -f "$stale"  ]] || { echo "no such file: $stale"  >&2; exit 2; }

python3 - "$accept" "$stale" <<'PY'
import sys

accept_path, stale_path = sys.argv[1], sys.argv[2]

# Stale (formula, id) pairs to drop.
stale = set()
with open(stale_path) as fh:
    for ln in fh:
        parts = ln.split()
        if len(parts) >= 2:
            stale.add((parts[0], parts[1]))

if not stale:
    print("no stale accepts — nothing to do")
    sys.exit(0)

with open(accept_path) as fh:
    lines = fh.read().splitlines()


def is_header(s):
    return s.lstrip().startswith("# ---")


def is_comment(s):
    return s.strip() == "" or s.lstrip().startswith("#")


out, removed = [], []
i, n = 0, len(lines)

# Preamble: everything before the first section header, verbatim.
while i < n and not is_header(lines[i]):
    out.append(lines[i])
    i += 1

# Sections: a header line plus everything up to the next header / EOF.
while i < n:
    sec = [lines[i]]
    i += 1
    while i < n and not is_header(lines[i]):
        sec.append(lines[i])
        i += 1

    kept, had_data, keep_data = [], False, False
    for s in sec:
        if is_comment(s):
            kept.append(s)
            continue
        had_data = True
        f = s.split()
        if len(f) >= 2 and (f[0], f[1]) in stale:
            removed.append((f[0], f[1]))
            continue
        kept.append(s)
        keep_data = True

    # A section that existed only to hold an accept that is now gone: drop it,
    # comment block and all. A section with a surviving accept is kept whole.
    if had_data and not keep_data:
        continue
    out.extend(kept)

# Tidy the blank lines a dropped section can leave behind.
collapsed = []
for s in out:
    if s.strip() == "" and collapsed and collapsed[-1].strip() == "":
        continue
    collapsed.append(s)
while collapsed and collapsed[-1].strip() == "":
    collapsed.pop()

with open(accept_path, "w") as fh:
    fh.write("\n".join(collapsed) + "\n")

for formula, cve_id in removed:
    print(f"removed stale accept: {formula} {cve_id}")
print(f"reconciled: {len(removed)} stale accept(s) removed")
PY
