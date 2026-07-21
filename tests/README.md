# tests/

Phase-1 checks for the chezmoi dotfiles repo. Full design: [../TESTING.md](../TESTING.md).
These files are **source-only** — `.chezmoiignore` keeps `tests/` and `TESTING.md` out
of `$HOME` (the `.mise.toml` task file is a root dot-file, auto-ignored by chezmoi).

## Run

```bash
mise run test                  # everything (mise trust once, first time)
mise run test:hermetic         # skip network checks (schema + leak only)
mise run check exist           # a single check: schema|exist|security|prune|leak
mise tasks                     # list all tasks

# or call the runner directly (no mise needed):
./tests/run.sh
./tests/run.sh --offline schema leak
```

Exit code is non-zero if any check fails. Warnings never fail the run.

Issues print twice by design: inline where they occur (debug context), then
re-collected in a `-- issues --` block per script and a labeled
`==== issues to action ====` list at the end of `run.sh` (failures first).

## Checks (`tests/lib/`)

| Script | ID | What it does | Network |
|---|---|---|---|
| `check_render.sh`          | A1 | hermetic render matrix: every template × every synthetic profile (`tests/fixtures/`), op faked by `tests/stubbin/op`; machine-guard + .chezmoiignore routing assertions | no |
| `check_lint.sh`            | A2 | lint rendered scripts (personal+work profiles) + raw shell: bash -n, shellcheck (errors), fish -n | no |
| `check_packages_schema.sh` | A3 | packages.yaml valid, no dup/cross-list dup, mas id+name | no |
| `check_packages_exist.sh`  | A4 | every brew/cask exists upstream; mas ids (advisory) | yes |
| `check_security.sh`        | A7 | deprecated/**disabled** (all pkgs); archived/stale + CVE via `brew vulns` (added pkgs) | yes |
| `prune_guard.sh`           | B2 | `brew bundle cleanup` dry-run: removals recently declared in packages.yaml (last `PRUNE_HISTORY_DEPTH`=5 revs, + their orphaned deps) → WARN; never-declared → FAIL over `--max`; > `PRUNE_EXCUSED_MAX`=10 excused → FAIL (bad merge) | brew |
| `leakscan.sh`              | §6 | no `{{ .work.user/companyname/domain }}` value in the tree | resolves via chezmoi |
| `render_brewfile.sh`       | —  | renders the installer's Brewfile (used by prune_guard) | no |

## In-apply hooks (`.chezmoiscripts/`, run by `chezmoi apply` — not in `tests/`)

| Script | When | Blocks apply? | Calls |
|---|---|---|---|
| `run_before_01_preflight` | every apply | **yes** | leak scan + prune-guard `--max ${PRUNE_MAX:-5}` |
| `run_onchange_after_00-00_package-audit` | on `packages.yaml` change | no (`PACKAGE_AUDIT_STRICT=1` to gate) | existence + security |

Upgrades are gated by `brew safe-upgrade --min-age 7` (age hold + OSV/NVD/GitHub CVE
check + SHA verify) in the daily updater — not by an in-apply scan. See TESTING.md §7.

## Daily updater (`tests/wrapper/daily_update.sh`, `mise run update`)

`safe-upgrade --self` → `safe-upgrade --yes --min-age 7` → reconcile pass
(`safe-install` over the declared set, which retries installs previously *held* by
the age gate — safe-upgrade alone can't see never-installed packages) → **staleness
cap**: packages held on every run for > `STALENESS_CAP` (21) days are starving
(release cadence outpaces min-age). Default: **report only** with the escape
command. `--upgrade-capped` / `UPGRADE_CAPPED=1` (`mise run update:auto`, for the
scheduled daily job) force-upgrades them with `--min-age 0` — still CVE/SHA
checked. Held-since state: `~/.cache/chezmoi-dotfiles-tests/held_since.txt`.
`chezmoi apply` never forces.

Final step: **sudo summary** — pkg-installer casks (mactex, tailscale-app, …)
can't `sudo installer` unattended; failures are detected, the affected casks
listed (age-held ones excluded), and a macOS notification posted so you know an
interactive `mise run update` (Touch ID sudo) is due.

**Scheduling:** the `io.nettleton.brew-update` LaunchAgent (chezmoi-managed,
reloaded on change by `run_onchange_after_00`) runs the `--upgrade-capped`
variant daily at 10:00; log at `~/Library/Logs/io.nettleton.brew-update.log`.

Note: safe-upgrade is installed early by `run_before_00_bootstrap.sh` (the gate must
exist before the gated installer runs) but stays declared in packages.yaml — the
1Password pattern — so it's prune-safe and audited like any other package.

Shared helpers: `common.sh` (logging/counters/paths), `pkg.sh` (yaml accessors + Homebrew JSON API cache).

## CI (`.github/workflows/test.yml`)

- **tier-a** (ubuntu, every push/PR + daily cron): schema, render matrix, lint,
  existence, deprecation/abandonment, leak scan (authoritative iff the
  `WORK_USER`/`WORK_COMPANYNAME`/`WORK_DOMAIN` repo secrets are set).
- **tier-b** (macos): chunked `brew vulns` (`tests/lib/ci_cve_scan.sh` — batches
  of 10 + per-package fallback; one big query hits OSV's read timeout) over the
  rendered core-only Brewfile at **latest** versions; job fails on high/critical.
  `cve_scan_skiplist.txt` holds packages too OSV-heavy to scan at all (vim) —
  still covered by safe-upgrade at upgrade time. Actions SHA-pinned.
  Known gap: `brew vulns` resolves packages via source repos, so **casks are
  absent** from the scan (~98 formulae) — casks rely on safe-upgrade's NVD
  mapping at upgrade time and their own self-updaters.

## Git pre-commit hook

`.githooks/pre-commit` runs the leak scan and **blocks any commit** that contains a
work/personal identifier value (bypass: `git commit --no-verify`). Activated via
`git config core.hooksPath .githooks` — done automatically per machine by
`.chezmoiscripts/run_once_after_00-04_configure-git-hooks.sh`.

## Config

- `prune_allowlist.txt` — package removals the prune-guard may permit (keep empty).
- `leak_allowlist.txt` — path globs exempt from the leak scan (keep empty).
- `deprecation_allowlist.txt` — deprecated packages consciously accepted (WARN → note).
  Does **not** silence a *disabled* package — that always fails.
- `mas_allowlist.txt` — MAS ids acknowledged as absent from iTunes lookup, e.g.
  legacy ids kept deliberately after Apple re-released the app under a new id
  (WARN → note).

## Notes

- Written for macOS `/bin/bash` 3.2 (no `declare -A` / `mapfile`) so the same
  scripts can back the in-apply preflight (TESTING.md §3.1).
- The leak scan never prints the secret value (redacted to `****`); set
  `WORK_USER` / `WORK_COMPANYNAME` / `WORK_DOMAIN` to run it without chezmoi.
- On machines without work-item access (wife/child), the work identifiers can
  never resolve — the scan (and the preflight step invoking it) skips cleanly.
- HTTP results cache under `${XDG_CACHE_HOME:-~/.cache}/chezmoi-dotfiles-tests`
  (6h TTL) — outside the repo.
- CVE scanning uses `brew vulns` — a built-in Homebrew command since it merged
  into Homebrew/brew (the `homebrew/brew-vulns` tap is archived). If an older brew
  lacks it, A7 notes that and skips the CVE step (update via `brew update`). The
  merge dropped `--cyclonedx`/`--sarif`, so there's no SBOM/dependency-graph feed;
  the CI job gates on high/critical findings only.
