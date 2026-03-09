# Chezmoi Dotfiles Roadmap

Audit conducted 2026-03-07. This document captures findings, potential architecture decisions, and a proposed plan of action.

---

## 1. Consolidate Machine-Targeting Logic

### Problem

There are **three different idioms** used to guard code by machine type, scattered across 30+ locations:

| Idiom | Meaning | Used in |
|---|---|---|
| `contains .chezmoi.username .targetname` | "is this a work machine?" | config.fish, pip.conf, npmrc, netrc, uv.toml, kitty.conf, chezmoiignore, run_once_04, run_once_05, run_once_90 |
| `eq .targetname "starship"` | "is this my personal desktop?" | config.fish, calBuddy/config.toml, run_once_04, ssh/config |
| `not (or (eq .targetname "nessie") (eq .targetname "cooper"))` | "is this a work machine?" (inverse) | ssh keys, gitconfigs, notes.kittysession, getCalendarEvents.js, run_once_04 |

The third idiom is the most fragile — it's an open-coded denylist that must be updated every time a personal machine is added. It's also logically equivalent to `contains .chezmoi.username .targetname` in some but not all contexts (e.g., "cooper" doesn't contain the work username).

### Recommendation

**ADR-1: Define semantic boolean flags in `.chezmoi.toml.tmpl`.**

Add computed/prompted data like:
```toml
[data]
  is_work_machine = true/false
  is_personal_machine = true/false
  is_server = true/false
```

Or derive them in templates from a single `machine_role` field (`"work"`, `"personal"`, `"server"`).

Then replace all three idioms with `{{ if .is_work_machine }}` everywhere. This:
- Eliminates the fragile denylist pattern
- Makes the intent readable at each usage site
- Means adding a new machine only requires answering one prompt, not updating N template guards

### Scope

~30 files need guard updates. Can be done incrementally by replacing one idiom at a time.

---

## 2. Adopt Modern Chezmoi Features

### 2a. `.chezmoiscripts/` directory (chezmoi 2.27+)

**Problem:** All 13 `run_once_*` scripts live at the repo root, cluttering it. Chezmoi now supports a `.chezmoiscripts/` directory for organizing scripts.

**Recommendation (ADR-2a):** Move all `run_once_*` scripts into `.chezmoiscripts/`. No functional change, just organization.

### 2b. `.chezmoiexternal` for external dependencies (chezmoi 2.1+)

**Problem:** `run_once_02_configure-fish.sh.tmpl` manually curls fisher and installs plugins. The whisper model download in `run_once_04` is similar manual fetching.

**Recommendation (ADR-2b):** Use `.chezmoiexternal.toml` for fisher and other downloaded artifacts. Example:
```toml
[".config/fish/functions/fisher.fish"]
  type = "file"
  url = "https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish"
  refreshPeriod = "168h"
```

This gives chezmoi native control over external downloads with refresh periods and checksums.

### 2c. `run_onchange_` instead of `run_once_` for package lists (chezmoi 2.0+)

**Problem:** `run_once_` scripts only run once per content hash. If you add a new brew package, the script re-runs entirely. But if you manually install something and the script content hasn't changed, it won't run.

**Recommendation (ADR-2c):** Convert `run_once_03_install-packages.sh.tmpl` and `run_once_98_install_mas_apps.sh.tmpl` to `run_onchange_` scripts. They already effectively behave this way (chezmoi hashes the rendered content), but the naming makes the intent clearer. `brew bundle` is already idempotent, so re-running on change is safe.

### 2d. Chezmoi `scriptEnv` for shared environment variables

**Problem:** Multiple scripts set up `SUDO_ASKPASS`, `HOMEBREW_GITHUB_API_TOKEN`, etc. independently.

**Recommendation (ADR-2d):** Use `[scriptEnv]` in `.chezmoi.toml.tmpl` for variables needed across scripts:
```toml
[scriptEnv]
  HOMEBREW_GITHUB_API_TOKEN = "{{ onepasswordRead ... }}"
```

### 2e. `.chezmoiignore` for machine-role exclusion

**Problem:** The `.chezmoiignore` currently uses the same scattered idioms (`contains .chezmoi.username .targetname`, etc.) to exclude files.

**Recommendation:** After ADR-1 (semantic flags), `.chezmoiignore` can use the clean `{{ if .is_work_machine }}` guards, and more files that are currently guarded inside their templates with `{{ if ... }}...{{ end }}` wrapping the entire content could instead be excluded via `.chezmoiignore`. This is cleaner — the file simply doesn't exist on the wrong machine rather than being an empty file.

### 2f. `age` encryption as alternative to 1Password template lookups (optional)

Currently all secrets go through 1Password `op read` / `onepasswordRead`. This is fine if 1Password is always available. Chezmoi's native `age` encryption could serve as a fallback or complement. **Low priority; current approach works.**

---

## 3–4. Script Modularization & Idempotency — DONE

All issues from the original audit (sections 3, 4, and 5) have been addressed:
- Monolithic `run_once_04` split into 13 focused scripts
- All scripts moved to `.chezmoiscripts/` with hierarchical numbering (00-05)
- Package lists extracted to `.chezmoidata/packages.yaml` (brew, fisher, npm, pip3, go, MAS)
- Package install scripts use `run_onchange_` to re-run when lists change
- `run_once_95` (manual steps) automated as `00-02_configure-sshd`
- `run_once_99` (whalebrew) deleted; packages merged into brew list
- `$account` bug removed, `tide configure` removed, `/etc/shells` automated
- SSH config deduplicated with `{{ define "1password" }}` template
- Idempotency guards added throughout `configure-macos` with diagnostic messages
- MailMate prompt guarded behind app existence check

---

## Proposed Plan of Action

### Phase 1: Quick wins (low risk, high value) — DONE (c52c1ab)
1. ~~**Fix bugs:** `$account` variable in run_once_04:114~~ — removed dead code
2. ~~**Remove dead code:** run_once_99~~ — deleted, merged 5 packages (awscli, helm, jq, kubernetes-cli, yq) into run_once_03; also removed whalebrew from brew list
3. ~~**Remove interactive blockers:** automate `/etc/shells` in run_once_01, remove `tide configure` from run_once_02, guard MailMate prompt in run_once_80~~
4. ~~**SSH config:** deduplicate IdentityAgent/IdentitiesOnly~~ — used `{{ define "1password" }}` template instead of `Host *`
5. ~~**SUDO_ASKPASS:** added clarifying comment to save/restore logic in run_once_03~~ — not a bug, just undocumented

### Phase 2: Semantic machine targeting (medium risk, high value) — DONE (a4fc0ba)
1. ~~Add `is_work_machine` / `is_personal_machine` / `is_wife_machine` / `is_child_machine` / `is_laptop` to `.chezmoi.toml.tmpl`~~
2. ~~Replace all six guard idioms across ~30 files~~
3. ~~Update `.chezmoiignore` to use new flags~~
4. ~~Reduce prompts from 9 to 2 (company, targetname) with smart defaults~~
5. ~~Derive workuser, workdomain, sudoItem, starshipuser, nessieuser from 1Password~~
6. ~~Add idempotency guards + diagnostic messages to run_once_90~~
7. ~~Add domain-snapshot-based conditional app restarts~~

### Phase 3: Script modularization (medium risk, medium value) — DONE
1. ~~Split `run_once_04` into focused per-tool scripts~~
2. ~~Move all scripts into `.chezmoiscripts/`~~
3. ~~Rename brew/MAS/npm/pip/go install scripts to `run_onchange_`~~
4. ~~Create `.chezmoidata/packages.yaml` for declarative package lists~~
5. ~~Merge git SSH key auth into unified `02-06_configure-git-auth`~~
6. ~~Automate sshd config (replacing manual steps script)~~
7. ~~Merge `run_once_01` (install fish) into brew package list~~
8. ~~Delete `run_once_95` (manual steps) and `run_once_99` (whalebrew)~~

### Future: split `05-01_configure-macos.sh.tmpl`
The macOS defaults script could be split by subsystem (UI, input, Finder, Dock, Safari, apps). The iTerm/Terminal color theme imports could move to `04-*`. Low priority since the script is mostly stable.

### Phase 4: Modern chezmoi features (low risk, medium value)
1. Add `[scriptEnv]` for shared env vars
2. Add `.chezmoiexternal.toml` for fisher and other downloads

### Phase 5: Cleanup (low risk, low value)
1. Audit macOS defaults script for settings that no longer apply to current macOS versions
