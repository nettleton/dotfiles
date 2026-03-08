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

## 3. Modularize the Run-Once Scripts

### Problem

Several scripts have grown into grab-bags of unrelated setup:

| Script | Unrelated concerns mixed together |
|---|---|
| `run_once_04_configure-packages.fish.tmpl` (145 lines) | Rust install, Go tools, npm packages, pyenv/Python, podman setup, docker-compose symlink, SwiftBar defaults, gh/glab auth, whisper.cpp model download, Tailscale config, calBuddy accounts+service, vale sync |
| `run_once_90_configure-macos.sh.tmpl` (~600 lines) | General UI, trackpad, energy, screen, Finder, Dock, Safari, Mail, Terminal, Time Machine, Activity Monitor, TextEdit, Photos, iCal, Contacts, dockutil |

### Recommendation (ADR-3): Split into focused scripts

**`run_once_04` should become multiple scripts:**
- `04a_configure-rust.fish.tmpl` — rustup install/update, cargo path
- `04b_configure-go.fish.tmpl` — GOPATH, go install tools
- `04c_configure-python.fish.tmpl` — pyenv, pip packages
- `04d_configure-node.fish.tmpl` — npm global packages
- `04e_configure-containers.fish.tmpl` — podman machine, docker-compose symlink, podman-mac-helper
- `04f_configure-dev-tools.fish.tmpl` — vale, whisper, misc dev tool setup
- `04g_configure-apps.fish.tmpl` — SwiftBar defaults, Tailscale, calBuddy, gh/glab auth

**`run_once_90` could be split by macOS subsystem** (lower priority since it's mostly stable):
- `90a_configure-macos-ui.sh.tmpl`
- `90b_configure-macos-input.sh.tmpl`
- `90c_configure-macos-finder.sh.tmpl`
- `90d_configure-macos-dock.sh.tmpl`
- `90e_configure-macos-safari.sh.tmpl`
- `90f_configure-macos-apps.sh.tmpl`

The macOS defaults script is adapted from mathiasbynens/dotfiles and changes rarely, so splitting it is lower value but improves debuggability when a single section causes issues.

---

## 4. Add Idempotency Guards

### Problem

Several scripts perform actions unconditionally that should first check if setup is already done. Some already have guards (good examples: `run_once_10` checks for `sudo_local`, `run_once_05` checks for existing SSH keys), but many don't.

### Specific gaps found:

| Location | Issue | Fix |
|---|---|---|
| `run_once_01` | No check if fish is already installed or already default shell | Guard with `command -v fish` and check `$SHELL` |
| `run_once_01` | Interactive `read` prompt blocks automation — asks user to edit `/etc/shells` | Check if fish is already in `/etc/shells`; add it with `sudo tee -a` if not |
| `run_once_02` | Always re-curls fisher and re-runs `fisher install` for all plugins | Check `functions -q fisher` before installing; fisher itself is idempotent but the curl is wasteful |
| `run_once_02` | Always runs `tide configure` (interactive) | Guard with a check or remove (tide settings are set programmatically right below) |
| `run_once_03` | `unset SUDO_ASKPASS` without restoring properly (the restore at end uses wrong var) | Fix the env save/restore logic |
| `run_once_04:23` | `go install vim-startuptime` runs unconditionally | Check if binary exists first |
| `run_once_04:65-66` | `pip install --upgrade` runs unconditionally | Already idempotent but slow; could skip if versions match |
| `run_once_04:75-78` | `sudo -A podman-mac-helper install` runs unconditionally every time | Check if helper is already installed |
| `run_once_04:82-83` | docker-compose symlink created unconditionally | Already uses `ln -sfn` so safe, but could skip with a check |
| `run_once_04:85-91` | SwiftBar defaults written unconditionally | Already idempotent via `defaults write`, acceptable |
| `run_once_04:93-98` | gh auth login checks exist but use `; or` which may not short-circuit properly in all cases | Verify fish `; or` behavior; consider `if not ... end` blocks |
| `run_once_04:112` | Tailscale defaults written unconditionally | Acceptable (idempotent) |
| `run_once_04:114` | calBuddy login uses undefined `$account` variable | Bug — `$account` is never set; this line likely does nothing |
| `run_once_80` | Interactive `read` prompt to wait for MailMate download | Check if `/Applications/MailMate.app` exists first; skip entirely if present |
| `run_once_90` | `sudo rm /private/var/vm/sleepimage` will error if file doesn't exist | Add `test -f` guard |
| `run_once_90` | `xattr -d com.apple.FinderInfo ~/Library` errors if xattr not present | Redirect stderr or guard |
| `run_once_99` | All whalebrew packages commented out; script just installs brews that are already in `run_once_03` | Likely dead code — consider removing or deduplicating |

### Recommendation (ADR-4): Add idempotency pattern

Establish a convention for all scripts:
```bash
# Pattern: check-then-act
if ! command -v fish &>/dev/null; then
  brew install fish
fi
```

For fish scripts:
```fish
# Pattern: check-then-act
command -v fish; or brew install fish
```

Audit each script and add guards. Fix the `$account` bug in `run_once_04:114`.

---

## 5. Additional Findings

### 5a. `run_once_99` is likely dead code

The whalebrew script has all whalebrew installs commented out and instead installs brew packages (`awscli`, `kubernetes-cli`, `helm`, `jq`, `yq`) that overlap with `run_once_03`. Consider removing this script entirely and adding any missing packages to the main brew list.

### 5b. `run_once_00` hardcodes the git remote

`run_once_00_convert_git_origin.sh` hardcodes `git@github.com:nettleton/dotfiles.git` and uses `cd .local/share/chezmoi` relative to `pwd` (fragile). This could be replaced with:
```bash
cd "$(chezmoi source-path)" && git remote set-url origin git@github.com:nettleton/dotfiles.git
```
Or better: this is a one-time bootstrap concern that may no longer be needed.

### 5c. `run_once_01` has a manual step that blocks automation

The script asks the user to manually edit `/etc/shells` via an interactive prompt. This can be fully automated:
```bash
grep -q "$FISH_PATH" /etc/shells || echo "$FISH_PATH" | sudo tee -a /etc/shells
```

### 5d. Duplicate `tide configure` + manual tide settings

`run_once_02` calls `tide configure` (interactive) and then immediately sets tide variables programmatically. The interactive step is redundant — the programmatic settings override whatever the user picks. Remove `tide configure`.

### 5e. SSH config has repeated `IdentityAgent` blocks

Every SSH host entry repeats the same `IdentityAgent` line. This could use a `Host *` wildcard:
```
Host *
  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

---

## Proposed Plan of Action

### Phase 1: Quick wins (low risk, high value)
1. **Fix bugs:** `$account` variable in run_once_04:114, env save/restore in run_once_03
2. **Remove dead code:** run_once_99 (or merge missing packages into run_once_03)
3. **Remove interactive blockers:** automate `/etc/shells` in run_once_01, remove `tide configure` from run_once_02, guard MailMate prompt in run_once_80
4. **SSH config:** add `Host *` block for `IdentityAgent`, remove per-host duplication

### Phase 2: Semantic machine targeting (medium risk, high value)
1. Add `is_work_machine` / `is_personal_machine` to `.chezmoi.toml.tmpl`
2. Replace all three guard idioms across ~30 files
3. Update `.chezmoiignore` to use new flags
4. Move whole-file guards into `.chezmoiignore` where the entire file content is wrapped in one conditional

### Phase 3: Script modularization (medium risk, medium value)
1. Split `run_once_04` into focused scripts (04a-04g)
2. Move all scripts into `.chezmoiscripts/`
3. Add idempotency guards to each new script
4. Rename `run_once_03` and `run_once_98` to `run_onchange_`

### Phase 4: Modern chezmoi features (low risk, medium value)
1. Add `[scriptEnv]` for shared env vars
2. Add `.chezmoiexternal.toml` for fisher and other downloads
3. Review remaining `run_once_` vs `run_onchange_` naming

### Phase 5: Cleanup (low risk, low value)
1. Evaluate whether `run_once_00` is still needed
2. Audit macOS defaults script for settings that no longer apply to current macOS versions
3. Consider splitting `run_once_90` by subsystem (optional)
