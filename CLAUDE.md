# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A [chezmoi](https://www.chezmoi.io/) dotfiles repository for macOS. Chezmoi manages dotfiles across multiple machines by maintaining source templates here (`~/.local/share/chezmoi/`) and applying them to the home directory.

## Key Commands

```bash
chezmoi apply                  # Apply all changes to home directory
chezmoi apply --dry-run        # Preview what would change
chezmoi diff                   # Show diff between source and destination
chezmoi edit <file>            # Edit a managed file (opens source)
chezmoi add <file>             # Add a new file to chezmoi management
chezmoi execute-template < file.tmpl  # Test template rendering
```

## Chezmoi Naming Conventions

Files use chezmoi's naming scheme to control behavior:
- `dot_` prefix → `.` in target (e.g., `dot_gitconfig.tmpl` → `~/.gitconfig`)
- `private_` prefix → file gets restrictive permissions
- `.tmpl` suffix → file is a Go template, rendered with data from `.chezmoi.toml.tmpl`
- `run_once_` prefix → scripts that run once per content change
- `run_onchange_` prefix → scripts that re-run whenever their rendered content changes (for package lists)
- `after_` attribute (`run_once_after_`, `run_onchange_after_`, `run_after_`) → script runs after ALL files/externals are applied
- Scripts are ordered alphabetically within their phase; numeric prefixes control execution order

## Important Constraints

- **Cannot call `chezmoi` from within a chezmoi script** — chezmoi holds a lock during apply, so `chezmoi source-path` etc. will timeout. Use hardcoded paths like `$HOME/.local/share/chezmoi`.
- **Template whitespace**: `{{-` and `-}}` trim whitespace. Both are needed on guards before shebangs (e.g., `{{- if ... -}}`) to avoid blank lines before `#!/bin/bash`.
- **Script/file ordering**: chezmoi orders update-phase entries by target path, and scripts in `.chezmoiscripts/` keep the `.chezmoiscripts/` prefix in that sort — which sorts BEFORE every home dotfile (`.config/…`, `.gitconfig`, …). A plain `run_once_`/`run_onchange_` script in `.chezmoiscripts` therefore never sees same-apply dotfile updates, and if it fails it aborts the apply before any dotfile lands. For this reason every non-bootstrap script here uses the `after_` attribute (files and externals are guaranteed to be applied first); only true bootstrap uses `run_before_`. Never add a plain (no-attribute) script to `.chezmoiscripts`.
- **`brew bundle`** does not support `--no-lock`.

## Architecture

### Configuration Data (`.chezmoi.toml.tmpl`)
All template variables are defined here. Only 2 interactive prompts (company, targetname) with smart defaults. Key data sections:
- `.targetname` — identifies which machine (e.g., "starship", "nessie", or work hostnames)
- `.is_work_machine`, `.is_personal_machine`, `.is_wife_machine`, `.is_child_machine`, `.is_laptop` — semantic boolean flags derived automatically
- `.personalpackages` — boolean toggling personal vs work-only package sets (derived from `not .is_work_machine`)
- `.work.*` — work domain, username, hostnames (derived from 1Password)
- `.op.*` — 1Password item references for secrets (SSH keys, tokens)

### Package Data (`.chezmoidata/packages.yaml`)
Declarative package lists for brew (taps, brews, casks, personal variants), fisher, go, and Mac App Store apps. Referenced in templates as `.packages.*`. Editing this file triggers `run_onchange_` scripts to re-run.

### Tool Versions (`dot_config/mise/config.toml`)
Python, Node, and their global packages (npm, pip) are managed by mise. This replaces pyenv and brew-installed node.

Note: `nettleton/tap` is a private repo fetched over HTTPS via the gh credential helper (`[credential "https://github.com"]` in dot_gitconfig) — deliberately not SSH, which would route `brew update` through the 1Password agent and prompt during unattended runs. `run_once_after_00-05` converts pre-existing SSH clones.

### External Downloads (`.chezmoiexternal.toml`)
Manages `fisher.fish` with weekly refresh via chezmoi's native external file support.

### Scripts (`.chezmoiscripts/`)
Two phases. `run_before_` scripts run before anything is applied (bootstrap only). Everything else carries the `after_` attribute (`run_once_after_` / `run_onchange_after_`) and runs after all files and externals are applied, so scripts always see current dotfiles. Within the after phase, scripts order alphabetically by their numeric prefix; `run_once_after_` and `run_onchange_after_` interleave.

**Bootstrap** (`run_before_`)
- `00` — Install Homebrew, 1Password, 1Password CLI, safe-upgrade if missing; prompt for sign-in
- `01` — Preflight checks

**`00-*` System config** (`run_once_after_`)
- `00-00` — Convert git origin to SSH
- `00-01` — Configure sudo Touch ID
- `00-02` — Configure remote access: sshd + Screen Sharing (non-work machines only)
- `00-03` — 1Password shell plugins (op plugin init brew)
- `00-04` — Install repo git hooks
- `00-05` — Convert nettleton/tap clone from SSH to HTTPS

**`01` Install brew packages** (`run_onchange_after_`)
- Fails fast (before installing or pruning anything) if the op token doesn't resolve or the private tap is unreachable; if the gh credential helper can't serve credentials yet (fresh machine), falls back to an inline token helper via `GIT_CONFIG_*` env vars scoped to the script
- Renders the Brewfile to a temp file (single source of truth: taps install and the prune both read it)
- Taps via a taps-only `brew bundle`; `trusted: true` on a tap entry emits the Brewfile `trusted:` keyword. Tap-trust state itself is declarative: `~/.homebrew/trust.json` is a chezmoi-managed template (`private_dot_homebrew/`) rendered from the same taps list, so ad-hoc trust drift is reverted on every apply
- Installs declared brews/casks via `brew safe-install --min-age 7` (age hold + CVE check + SHA verify; already-installed packages skip fast and are never upgraded here — upgrades go through the daily gated `safe-upgrade`). Held/vulnerable packages are skipped, picked up later by the daily updater's reconcile pass
- Prunes drift: `brew bundle cleanup --brews --casks` uninstalls any formula/cask not declared in the config (prints the plan, then `--force`). Scoped to brews+casks only — NOT taps/mas/go, which are separate managers absent from this Brewfile. Dependency closure of declared packages is preserved.
- Personal packages gated on `.personalpackages`
- Re-runs automatically when `packages.yaml` brew lists change
- Auth via 1Password shell plugin; the op-sourced GitHub token is exported as `GH_TOKEN` for safe-install's release-age checks

**`02-*` Configure brew-installed packages** (`run_once_after_`)
- `02-00` — Fish shell (/etc/shells, chsh, fisher plugins, tide settings)
- `02-01` — Rust (rustup, CARGO_HOME)
- `02-02` — Go (GOPATH/GOBIN, /usr/local/netbin on work machines)
- `02-03` — mise install (Python, Node, Java, npm/pip packages; `run_onchange_after_`, re-runs when mise config changes)
- `02-04` — Containers (podman machine, podman-mac-helper, docker-compose symlink)
- `02-05` — SwiftBar defaults
- `02-06` — Git auth (gh/glab login + SSH key upload to GitHub/GitLab)
- `02-07` — TeamCity auth (work machines)
- `02-08` — Tailscale defaults
- `02-09` — calBuddy (account login, sync service; retries via exit 1 if calBuddy isn't installed yet)
- `02-10` — Vale sync

**`03-*` Install packages via other managers** (`run_onchange_after_`)
- `03-02` — Go binaries from `.packages.go`
- `03-03` — Internal packages (work machines)

**`04-*` Install & configure apps** (mixed)
- `04-00` — Configure MailMate (`run_once_after_`; installed via `mailmate@beta` cask)
- `04-01` — Install Mac App Store apps (`run_onchange_after_`, from `.packages.mas.*`)

**`05-*` macOS system configuration** (`run_once_after_`)
- `05-00` — Setup other users
- `05-01` — macOS UI/UX and input (computer name, dark mode, trackpad, keyboard, locale)
- `05-02` — Energy saving (pmset, hibernation guarded by `is_laptop`)
- `05-03` — Screen (screenshots, screensaver password)
- `05-04` — Finder (views, sidebar, Library visibility)
- `05-05` — Dock, Mission Control, hot corners (all disabled), dock item removal
- `05-06` — App defaults (Safari, Mail, Spotlight, Terminal/iTerm, Chrome, Activity Monitor, TextEdit, etc.)
- `05-07` — Conditional app restarts (Dock/Finder unconditional, others prompted)

**`99-*` End of apply**
- `run_after_99-00_fix-permissions` — chmod ~/.netrc (every apply)
- `run_onchange_after_99-01_load-brew-update-agent` — bootstraps/reloads the
  `io.nettleton.brew-update` LaunchAgent (daily gated brew updater, 10:00,
  `daily_update.sh --upgrade-capped`) whenever its chezmoi-managed plist changes

### Conditional Targeting
Templates use semantic boolean flags (`.is_work_machine`, `.is_personal_machine`, etc.) to conditionally include config per machine. The `.chezmoiignore` file also conditionally excludes files based on these flags.

### Secrets Management
All secrets are fetched from 1Password via `op read` or chezmoi's `onepasswordRead` template function. SSH public keys are stored as `.tmpl` files that resolve 1Password references at apply time. Homebrew auth uses the 1Password shell plugin (sourced in fish config).

### SSH Configuration (`private_dot_ssh/`)
SSH config and keys are templated per-machine. The 1Password SSH agent is used for all hosts (`IdentityAgent` points to the 1Password agent socket). Config uses `{{ define "1password" }}` template to deduplicate agent settings.

### Managed Configs (`dot_config/`)
Includes config for: fish shell, neovim (Lua-based with lazy.nvim), kitty, starship prompt, karabiner, gh/glab CLIs, SwiftBar plugins, fd, vale, zk, calBuddy, and others.
