# Testing Plan — chezmoi dotfiles

Status: **Phases 1–2 built** (see §10); Phases 3–4 designed. This document is the
blueprint for a test suite whose purpose is to safely gate automated, unattended
package upgrades (`brew safe-upgrade`, `mise up`, fisher/go updates, `chezmoi apply`).

This file and everything under `tests/` are **chezmoi-ignored** — they live in the
source repo only and are never applied to `$HOME`.

---

## 1. Why a test suite is Step 1 for auto-updates

An auto-updater runs package upgrades unattended and opens a PR. That is only safe
if a test suite can automatically answer three questions:

1. **Did the config break?** — templates still render, scripts still lint, Neovim
   and fish still load.
2. **Did the package graph break?** — every declared package still exists upstream;
   nothing was silently renamed or removed.
3. **Will `apply` do something destructive?** — the Homebrew prune step won't
   mass-uninstall.

The suite is the gate the automation merges against, so it is built first.

## 2. Highest-risk surfaces in this repo (what the tests must protect)

- **The Homebrew prune** in `.chezmoiscripts/run_onchange_after_01_install-brew-packages.sh.tmpl`
  runs `brew bundle cleanup --force`, which uninstalls anything not declared in
  `packages.yaml`. A typo or an upstream formula rename could trigger a mass
  uninstall. This is the single most dangerous operation under auto-update.
- **Everything is templated.** `.chezmoi.toml.tmpl` calls `onepassword`, `op read`,
  and `sysctl` at init, so naive rendering fails without a Mac + signed-in
  1Password. Tests need a hermetic rendering path (§4).
- **macOS-only surface** — casks, `mas` (Mac App Store, needs a signed-in account),
  `defaults`, launchd. A plain Linux runner can never fully `apply` this repo.
- **Frequent-breakage surfaces** — Homebrew formula renames/removals, and Neovim
  plugin/LSP breakage on `neovim` upgrades.
- **PII / identifier leakage** — personal and work identifiers must never be
  committed anywhere in the repo, including test fixtures and golden files (§6).

## 3. Architecture: three tiers by where a test can run

The repo spans hermetic data all the way to a signed-in physical Mac, so tests are
split by **where they can run**. The fast/safe tier gates every push; the expensive
tier runs on the real machine.

| Tier | Runs on | Needs | Gates | Cadence |
|---|---|---|---|---|
| **A — Hermetic** | Linux, GitHub-hosted Actions, pre-commit | nothing (stubs + fixtures) | every push/PR | seconds |
| **B — macOS, no secrets** | GitHub-hosted `macos-latest` | Homebrew, no 1Password | package-upgrade PRs | 1–3 min |
| **C — Real machine** | the actual Mac, **inside `chezmoi apply`** | 1Password signed in, App Store | every apply (incl. the daily auto-update) | full run |

**No self-hosted runner.** Tiers A and B run on GitHub-*hosted* runners
(`ubuntu-latest` / `macos-latest`) — no persistent infrastructure to own. Tier C does
**not** get a runner at all; instead its safety checks run **as a preflight inside
`chezmoi apply` itself** (§3.1), so every apply — interactive or the daily automated
one — is gated locally with zero extra infrastructure.

### 3.1 Where the Tier-C gate lives (the preflight model)

The hard constraint: **a chezmoi script cannot call `chezmoi`** — apply holds an
exclusive lock, so `chezmoi apply --dry-run`, `verify`, `data`, `managed`, and
`execute-template` all deadlock if invoked from within a script (see CLAUDE.md). That
splits Tier C in two:

- **Blocking checks that don't call chezmoi** → run as an **in-apply preflight** that
  aborts before the mutating scripts:
  - `run_before_01_preflight.sh.tmpl` — runs first on **every** apply. Fast,
    local-only: leak scan (§6) and prune-guard preview (B2). Because it is a template,
    chezmoi injects `{{ .work.user }}` etc. directly, so the leak scan needs no
    `chezmoi data` call. Non-zero exit aborts the apply before anything is touched.
  - `run_onchange_after_00-00_package-audit.sh.tmpl` — runs **only when `packages.yaml`
    changes** (its rendered content is hashed), ordered before the installer
    (`00` < `01`). Checks that only matter when the *declared set* changes: existence
    (A4) and deprecation/disabled (A7). A failure stops the apply before
    `run_onchange_after_01` installs or prunes anything. (The **latest-version CVE** scan of
    the declared set is done in CI, not here — see below.)
- **Checks that must call chezmoi** (`apply --dry-run`, `verify`, secret-render) →
  can't run inside apply. They live in a **thin local wrapper** the daily job runs
  *around* chezmoi — a `launchd` plist (or cron, or a Claude Code agent) that does
  `preflight → chezmoi apply --dry-run → review → chezmoi apply`. This is a plain
  shell script on the Mac, **not** a self-hosted CI runner.

> **No installed-version CVE scan on apply.** An earlier design ran `brew vulns` over
> the whole installed closure after every apply. It was dropped: `brew vulns` sends
> each batch as one OSV request with a fixed read timeout, so a full-machine scan
> reliably times out (`Net::ReadTimeout`) — even chunked it fails intermittently. That
> job is better served by `brew safe-upgrade` (checks only *outdated* packages — a
> small set — across OSV + NVD + GitHub Advisory) plus Dependabot alerts. See §7.

Escape hatch: the preflight honors `PREFLIGHT_SKIP=1` and degrades gracefully when
offline (still hard-gates the local leak scan + prune-guard; skips network checks with
a warning).

## 4. Hermetic-rendering harness (unblocks Tier A)

`.chezmoi.toml.tmpl` calls `onepassword`, `op read`, and `sysctl` at init — the
blocker to rendering anywhere. Solve it two ways, both in-repo under `tests/`:

- **Stub binaries** — `tests/stubbin/` holds fake `op` and `sysctl` scripts that echo
  fixture output. Put it first on `PATH` (and/or point `[onepassword].command` at the
  stub) so even `chezmoi init` renders hermetically.
- **Fixture configs** — pre-baked static `tests/fixtures/{personal,work,wife,child,laptop}.toml`
  holding the `[data]` block each machine profile produces. Render with
  `chezmoi execute-template --config <fixture>` to bypass the init prompts.

This yields a **render matrix**: every `*.tmpl` × every machine profile.

> **Fixtures and golden files MUST use synthetic data** — never real identifiers.
> Use obvious fakes (`workuser = "acme"`, `domain = "acme.example"`,
> `companyname = "Acme"`, hostnames under `.example`/`.test`). Render tests then
> assert *structure/shape*, not real values. The leak scanner (§6) enforces this.

## 5. Test categories

### Tier A — Hermetic (Linux / CI / pre-commit)

**A1. Template renders**
- `chezmoi execute-template` every `*.tmpl` against every fixture profile → assert
  exit 0, non-empty where expected, and that machine-guarded files (e.g. work-only
  `run_onchange_after_03-03`) render empty on the profiles that should exclude them.
- `.chezmoiignore` yields the expected file set per profile (`chezmoi managed`).
- Golden-file snapshots for a few high-value **synthetic** renders (the Brewfile,
  SSH config) so diffs are reviewable.

**A2. Rendered-script lint**
- Render each script template, pipe to **shellcheck** (bash).
- **shfmt -d** for formatting.
- fish scripts: `fish -n` (parse-check) on rendered `.fish` output.

**A3. `packages.yaml` schema + hygiene** (pure data, high ROI)
- Valid YAML; each tap has `name`; `url`/`trusted` optional and correctly typed.
- **No duplicates** within any list; **no cross-list dupes** (a formula in both
  `brews` and `personal_brews`).
- No brew listed as a cask or vice-versa (classification cross-check with A4).
- `mas` entries have integer `id` + `name`.
- Optional: sorted-order check (aids diffs; the install script sorts at render time).

**A4. Package existence** (network, no auth — catches the #1 upgrade breakage)
- Brews/casks: query `https://formulae.brew.sh/api/formula/<x>.json` and
  `.../cask/<x>.json` → assert every declared package still exists upstream **and**
  is the right type. This catches an upstream rename/removal **before** it reaches
  the destructive prune.
- Taps: resolvable (`git ls-remote` for custom-URL taps; GitHub path for the rest).
- fisher plugins & go modules: repo/module path resolves.
- `mas` ids: `https://itunes.apple.com/lookup?id=<id>` returns a result.
- All read-only and unauthenticated → lives in Tier A.

**A5. Identifier / PII leak scan** (see §6 for the full design)

**A7. Package security & maintenance audit** (network, no auth — flags risky packages)
The auto-updater must not silently pull in a vulnerable or abandoned package, and must
flag **newly added** packages hardest. Three signals, cheapest/most-authoritative
first:

- **Homebrew deprecation/disable (all packages, authoritative, ~free).**
  `brew info --json=v2 <pkg>` reports `deprecated` / `disabled` (+ reason/date).
  Homebrew marks EOL and unmaintained formulae/casks this way, so this is the single
  best maintenance signal. **Hard-gate on `disabled`; flag on `deprecated`.**
  Consciously-accepted deprecations go in `tests/deprecation_allowlist.txt`
  (WARN → note); `disabled` can never be allowlisted (it can't be installed).
- **CVEs — via `brew vulns`** (the official `homebrew/brew-vulns` tap). It maps each
  formula to its upstream repo and queries **OSV's GIT ecosystem** — the right way to
  get real Homebrew coverage — and marks CVEs already patched by the formula as
  resolved (few false positives). Scan the rendered Brewfile or the *added* formulae;
  **hard-gate on `--severity high`** (exit 1). Casks aren't covered (formula-source
  based). This replaces an earlier hand-rolled name-only OSV query.
- **Abandonment (new packages).** Resolve the upstream repo from `brew info` homepage/
  source URL; via GitHub API check `archived` and last commit/release date. **Flag**
  if archived or no activity in ~18–24 months.

**Where each signal runs:**

| Signal | Where | Blocks? |
|---|---|---|
| deprecation / disabled | `run_onchange` package-audit + CI | yes (`disabled`) |
| existence, abandonment | `run_onchange` package-audit + CI | yes / flag |
| **added-package CVE** (`brew vulns`, small set) | `run_onchange` package-audit + CI | flag / gate in CI |
| **upgrade/install CVE + age + SHA** (`brew safe-upgrade`) | daily updater (§7) | skips vulnerable / holds too-fresh |
| **continuous installed CVE** (SBOM → Dependabot) | GitHub, server-side | alerts, immediate |

Deprecation is time-varying (e.g. `screens` became disabled without any edit), so the
package-audit also runs on the daily schedule, not only on `packages.yaml` change.
There is **no** installed-version `brew vulns` scan on apply — see the §3.1 note.

### Tier B — macOS, no secrets

**B1. Brewfile realizability** — render the Brewfile; `brew bundle check --file` and a
`brew bundle --dry-run` confirm the declared set is installable/consistent.

**B2. Prune-guard** (the critical safety test) — render the Brewfile and compute what
`brew bundle cleanup` *would* remove (dry-run, no `--force`). Removals are judged by
intent: a package declared in a **recent committed revision** of packages.yaml (last
`PRUNE_HISTORY_DEPTH`, default 5) but absent from the current list is a deliberate
edit → WARN only; orphaned dependencies of those are excused too (via `brew deps`).
Everything else — never-declared names (typo, upstream rename, ad-hoc drift) — FAILs
above `--max`, and more than `PRUNE_EXCUSED_MAX` (default 10) excused removals at once
FAILs regardless (a bad merge that dropped a block of declarations). This is the test
that stops an auto-update PR from wiping packages after a rename/typo. Same idea for the
(Tap trust needs no equivalent guard: `~/.homebrew/trust.json` is chezmoi-managed,
so trust drift is reverted declaratively by apply.)

**B3. Binary smoke tests** — after an upgrade, assert the key toolchain still runs:
`fish --version`, `nvim --version`, `starship`, `go version`, `gh`, `rg`, `fd`, `bat`,
`jq`, `mise --version`, etc.

**B4. Config-load smoke tests**
- Fish: `fish -c true` against the real config on a clean `$HOME` → no startup errors.
- **Neovim**: `nvim --headless "+Lazy! sync" +qa`, then
  `nvim --headless "+checkhealth" +qa`, grepping output for `ERROR`. Neovim upgrades
  are the most likely breakage. Add **stylua --check** and **luacheck** on
  `dot_config/nvim` (there is already a `.luarc.json`).
- kitty / starship / karabiner: each tool's own `--config`/validate check where one
  exists.

### Tier C — Real machine (in-apply preflight + local wrapper, no runner)

Runs on the actual Mac. Per §3.1, checks are placed by whether they call chezmoi.

**In the preflight scripts** (`run_before_01_preflight`, `run_onchange_after_00-00_package-audit`):
- **C1. Leak scan** — the §6 three-string scan, with `{{ .work.* }}` injected by the
  template (no `chezmoi data` call). Non-zero exit aborts the apply.
- **C2. Prune-guard** (B2) and **C3. package audit** (A4 + A7) — abort before the
  installer runs.

**In the local wrapper** the daily job runs *around* chezmoi (launchd/cron/agent):
- **C4. Secret rendering** — render the SSH pubkey `.tmpl`s / `op read` templates →
  assert they resolve (no unresolved `op://…`).
- **C5. `chezmoi apply --dry-run` / `chezmoi diff`** — full render vs real data, exit
  0, review the diff, then apply.
- **C6. `chezmoi verify`** — post-apply, target state matches source.
- **C7. `mas`** — `mas list` covers declared ids (App Store account required).
- **C8. Idempotency** — `apply` twice; second run is a stable no-op.

## 6. Identifier / PII leak scanner (§Phase-1 requirement)

**Goal:** no personal or work identifier appears anywhere in the committed tree —
scripts, templates, `packages.yaml`, test fixtures, golden files, or this doc.

**The representation problem:** a test that asserts "identifier `X` must never appear"
naively needs `X` written into the test — which puts `X` in the repo, the exact leak
it is meant to prevent. The denylist must therefore never exist in plaintext in the
repo. It is instead resolved from authoritative sources at test time, held in memory,
and discarded after the scan.

**Denylist (the three authoritative strings).**
The scan targets the *resolved values* of exactly these chezmoi template variables:

| Variable | Source |
|---|---|
| `{{ .work.user }}` | `.chezmoi.toml.tmpl` → `data.work.user` (1Password) |
| `{{ .work.companyname }}` | `.chezmoi.toml.tmpl` → `data.work.companyname` (1Password, `company` prompt) |
| `{{ .work.domain }}` | `.chezmoi.toml.tmpl` → `data.work.domain` |

Resolve them at runtime with `chezmoi data` (or `chezmoi execute-template` on each
`{{ .work.* }}`), then grep the committed tree **case-insensitively** for each value.
Because the values come from the config/1Password and are only ever held in memory,
nothing is stored in the repo — the scanner stays authoritative without leaking. On a
machine where these resolve empty (no work config), the scan is a no-op for that
value, so guard against empty strings (an empty denylist entry must not match
everything).

**Scope:** the entire committed tree, explicitly including `tests/fixtures/`,
`tests/golden/`, and this file. (This is why fixtures/goldens must use synthetic data
per §4 — a real value there would trip this scan.)

**Optional complement — structural heuristics.** A hermetic regex pass for the *shape*
of PII (emails, RFC1918 / public IPs, MAC addresses) can run in Tier A with no
secrets, catching leaks the three-string denylist would miss. Secondary to the exact
match above.

**Where it runs:**
- The three-string scan needs the resolved work values, so it runs wherever
  `chezmoi data` resolves them: Tier C / CI-with-secrets, and **before every
  auto-update PR is pushed** (scan the diff so an upgrade that introduces an
  identifier is blocked).
- The optional heuristic pass runs hermetically in Tier A / pre-commit.

## 7. Upgrade-flow: the security model

Three complementary layers, each answering a different question:

| Layer | Question | Mechanism | Timing |
|---|---|---|---|
| **Age-gated upgrades** | "is this new version too fresh / vulnerable?" | `brew safe-upgrade` | at upgrade (daily) |
| **CVE awareness** | "did a CVE just drop for something I have?" | SBOM → Dependabot alerts | immediate, continuous |
| **Change gating** | "did this diff break config / mass-prune / leak?" | the test suite (§5) + preflight (§3.1) | on change / on apply |

**`brew safe-upgrade` replaces plain `brew upgrade`** as the daily bump mechanism.
It gates every upgrade on: **release age** (`--min-age 7` — hold back formulae/casks
whose formula file was touched < 7 days ago, a supply-chain cushion), **vulnerabilities**
(OSV + NVD + GitHub Advisory, version-aware, deduped), **bottle SHA integrity**, and
**transitive deps**. Crucially, the age hold is **auto-bypassed when your installed
version has a known CVE** — a security fix is adopted immediately rather than waiting
out the 7 days. Non-interactive via `--yes` (upgrades clean packages, skips vulnerable
ones). `brew safe-install --min-age 7` gates *new* installs the same way, and the
package installer routes all declared installs through it (see below).

**safe-upgrade follows the 1Password bootstrap pattern** — installed early by
`run_before_00_bootstrap.sh` (tap + trust + install; the gate must exist before the
gated installer runs) while **remaining declared in `packages.yaml`**, so the prune,
the managed trust.json, and the A4/A7 package audits all treat it like any other
package. No special cases in the Brewfile.

**The package installer goes through the gate too.** `run_onchange_after_01` no longer does
a blanket `brew bundle` (which also *upgraded* every outdated declared package,
ungated). Instead: taps via a taps-only `brew bundle`, then
`brew safe-install --min-age 7` over declared brews and casks (installed → skipped
fast with no network and never upgraded; missing → age/CVE/SHA-gated; held → skipped
with exit 0), then the prune, unchanged and still reading the full rendered Brewfile.
Tap trust is declarative: `~/.homebrew/trust.json` is a chezmoi-managed template
rendered from the same packages.yaml taps, so ad-hoc trust drift is reverted on every
apply (no reconcile loop). Age checks hit the GitHub API, so the installer exports
the op-sourced token as `GH_TOKEN` (5000/hr vs 60/hr — a fresh-machine bootstrap would
otherwise rate-limit and fail closed).

> The 7-day wait lives here, on version **adoption** — not on CVE alerts. You want to
> *learn* about a CVE instantly (Dependabot), *hold* ordinary new versions for 7 days
> (safe-upgrade), and *fast-track* the actual security fixes (safe-upgrade's bypass).

**Security audit (2026-07-08, v0.2.9).** Full source + supply-chain audit before
adoption: no malicious code in the bash or Python layers; endpoints limited to
OSV/NVD/GitHub/formulae.brew.sh (+ read-only PyPI/npm version lookups); GH token sent
only to api.github.com; no eval/subprocess injection surface; installed files
byte-identical to the tagged source; formula tarball SHA matches the pin; CI is
SHA-pinned with CodeQL/gitleaks/pytest. Known caveats to re-check on major bumps:
(1) under `--yes`/non-TTY it fails **open** on SHA-API outage, dep-scanner failure,
and vulnerable *transitive* deps — hard unattended guarantees are only "no known-CVE
direct installs" and "no SHA-mismatched bottles"; (2) if all 3 vuln sources are
unreachable the scanner exits 0 "clean" (0/3 checked); (3) brew formulae with names
< 4 chars (jq, gh, go, fzf, vim…) are never CVE-queried — covered instead by our
`brew vulns` CI gate + Dependabot SBOM alerts (defense in depth); (4) never use the
curl-based `brew safe-update` — self-update only via `--self` (formula route,
SHA-pinned through tap PRs), which `daily_update.sh` already does; the repo's
"signed manifest" wording is inaccurate (unsigned checksums, same-channel).
Risk posture: young project (~2.5 mo), single maintainer — trust anchor is the
author's GitHub account; audit worth repeating at major version bumps.

**The auto-updater loop** (brew leg implemented: `tests/wrapper/daily_update.sh`,
run via `mise run update`):

1. **Bump** — `brew safe-upgrade --self` (keep the gate current), then
   `brew safe-upgrade --yes --min-age 7`, then a **reconcile pass**
   (`brew safe-install --min-age 7` over the declared set) — safe-upgrade only sees
   *installed* packages, so the reconcile is what picks up declared packages that were
   *held* at install time once they age past 7 days (installed ones skip in ~0.8s).
   Then the **staleness cap**: a package held on every run for > `STALENESS_CAP` (21)
   days is starving — its release cadence outpaces min-age, so the newest version is
   never old enough (Homebrew can only install the *current* formula version). Default
   is report-only; the scheduled daily job passes `--upgrade-capped` to force those
   through with `--min-age 0` (CVE/SHA checks still apply). `chezmoi apply` never
   forces. Later: `mise up`, fisher update, `go install …@latest`, `chezmoi update`.
2. **Gate** — Tier A (existence + deprecation + render + lint + leak scan) → Tier B
   (prune-guard + smoke + nvim health). Any red → don't open the PR / auto-revert. The
   same checks re-run as the in-apply preflight (§3.1), so the Mac is gated even if the
   PR path is skipped.
3. **Version capture** — snapshot `brew list --versions`, `mise ls`, fisher versions
   into a lockfile artifact so a bad upgrade is diffable and pin-able. (Homebrew has no
   real rollback; the fallback is pinning the last-good version in `packages.yaml`.)
4. **PR** — open with the version diff + test results for human/agent review.

**CVE monitoring (continuous, server-side).** Submit a CycloneDX SBOM to GitHub's
dependency graph so **Dependabot** matches CVEs server-side and alerts immediately — no
OSV-from-the-Mac flakiness. `brew vulns` is kept only for the small, reliable jobs:
the CI added-package gate (A7) and on-demand checks.

## 8. Tooling to add

- **Runner:** [`bats-core`](https://github.com/bats-core/bats-core) — natural fit for
  a bash/CLI repo; one `.bats` file per category above.
- **Linters:** `shellcheck`, `shfmt`, `yq`, `stylua`, `luacheck`, plus `fish -n`.
  Add these to `packages.yaml` so the test toolchain is itself managed.
- **Upgrade gate:** `brew safe-upgrade` / `brew safe-install`
  (`sharkyger/tap/safe-upgrade`, declared in `packages.yaml`) — age hold (`--min-age
  7`) + CVE check (OSV+NVD+GitHub) + SHA verify on every brew upgrade/install.
- **Security audit:** `brew vulns` (`homebrew/brew-vulns/brew-vulns`, declared) for the
  small CI added-package CVE gate + on-demand; `gh` for repo abandonment metadata;
  `brew info --json=v2` for deprecation. No hand-rolled OSV code.
- **Entrypoint:** repo-local **mise tasks** in `.mise.toml` (`mise run test`,
  `test:hermetic`, `check <name>`, …) so the tiers share one interface locally and in
  CI, consistent with the mise task convention used across the other repos. The
  preflight scripts call the same underlying `tests/lib/` scripts, so logic lives in
  one place.
- **Pre-commit:** `.githooks/pre-commit` runs the §6 leak scan and blocks the commit
  on a hit (bypass with `git commit --no-verify`). Activated via `core.hooksPath`
  (tracked in `.githooks/`, auto-ignored by chezmoi as a dot-dir); set per-machine by
  `run_once_after_00-04_configure-git-hooks`. **DONE.**
- **CI:** `.github/workflows/test.yml` — Tier A on `ubuntu-latest` for every push;
  Tier B on `macos-latest`. Both are GitHub-hosted; no self-hosted runner. A security
  job submits a CycloneDX SBOM to the dependency graph (→ **Dependabot** alerts,
  server-side, immediate) and runs the `brew vulns` added-package gate.
- **Local automation — DONE (brew leg):** `io.nettleton.brew-update` LaunchAgent
  (chezmoi-managed plist in `private_Library/LaunchAgents/`, bootstrapped/reloaded by
  `run_onchange_after_99-01_load-brew-update-agent` whenever the plist changes) runs
  `daily_update.sh --upgrade-capped` daily at 10:00, logging to
  `~/Library/Logs/io.nettleton.brew-update.log`. The chezmoi-calling wrapper checks
  (C4–C8) and the mise/fisher/go/mas legs remain Phase-4 work. The in-apply preflight
  (§3.1) gates the rest.

## 9. Proposed layout

```
tests/
  fixtures/    personal.toml, work.toml, wife.toml, child.toml, laptop.toml  # synthetic data only
  stubbin/     op, sysctl        # fake binaries for hermetic init
  golden/      brewfile.personal, ssh_config.work, …   # synthetic-render snapshots
  lib/         check_packages_exist.sh, check_security.sh, prune_guard.sh, leakscan.sh
               # plain scripts, shared by bats + the preflight (single source of truth)
  hermetic/    render.bats, lint.bats, packages_schema.bats, packages_exist.bats,
               security_audit.bats, leakscan.bats
  macos/       brewfile.bats, prune_guard.bats, smoke.bats, nvim_health.bats
  wrapper/     daily_update.sh          # driven by launchd; wraps chezmoi (C4–C8)
  helpers.bash render(), assert_renders(), brew_api(), denylist()
.mise.toml                     # repo-local mise tasks; dot-file → auto chezmoi-ignored
.github/workflows/test.yml     # .github is a dot-dir → auto chezmoi-ignored

# In-apply preflight (these ARE applied — they live in .chezmoiscripts, not tests/):
.chezmoiscripts/run_before_01_preflight.sh.tmpl        # leak scan + prune-guard, every apply (blocking)
.chezmoiscripts/run_onchange_after_00-00_package-audit.sh.tmpl  # existence + deprecation + added-CVE, on packages.yaml change
```

`tests/` and `TESTING.md` are listed in `.chezmoiignore` so they are never applied to
`$HOME`. (`.github/` and `.mise.toml` need no entry — chezmoi does not apply
dot-files/dot-directories at the source root.) The two preflight scripts under
`.chezmoiscripts/` are the
exception: they run *inside* apply by design, so they must **not** call `chezmoi`, and
they reference the repo via the hardcoded `$HOME/.local/share/chezmoi` path (per
CLAUDE.md) rather than `chezmoi source-path`.

## 10. Phased rollout

- **Phase 1 (highest ROI, do first):** `packages.yaml` schema + existence checks
  (A3/A4), the **security & maintenance audit** (A7), the **prune-guard** (B2), and
  the **identifier/PII leak scanner** (A5/§6) — implemented as reusable scripts in
  `tests/lib/`. These directly de-risk the auto-updater and need minimal scaffolding.
- **Phase 2 — DONE.** Wired the Phase-1 scripts into the in-apply lifecycle (§3.1):
  `run_before_01_preflight` (blocking: leak scan + prune-guard `--max`) and
  `run_onchange_after_00-00_package-audit` (non-blocking existence + deprecation + added-CVE;
  `PACKAGE_AUDIT_STRICT=1` to gate). No runner. (An installed-version `brew vulns`
  `run_after` was prototyped and dropped — see §3.1/§7; `safe-upgrade` covers it.)
- **Phase 3 — DONE.** Hermetic render matrix (A1: `tests/fixtures/` synthetic
  profiles × full-source `apply --dry-run`, op faked by `tests/stubbin/op`) and
  rendered-script lint (A2: bash -n + shellcheck + fish -n) — both in the local suite
  and in `.github/workflows/test.yml`: tier-a (ubuntu) runs the hermetic + package
  checks on every push/PR + daily cron; tier-b (macos) runs the desired-state
  `brew vulns` gate → SARIF code scanning + CycloneDX SBOM → dependency graph →
  Dependabot alerts. Leak scan in CI is authoritative iff WORK_* repo secrets are set.
- **Phase 4:** macOS smoke + nvim health (B3/B4) on `macos-latest`, then the local
  `launchd` wrapper (C4–C8) + the daily `brew safe-upgrade --min-age 7` flow (§7).
