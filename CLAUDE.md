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
- Scripts are ordered alphabetically across both types; numeric prefixes control execution order

## Important Constraints

- **Cannot call `chezmoi` from within a chezmoi script** — chezmoi holds a lock during apply, so `chezmoi source-path` etc. will timeout. Use hardcoded paths like `$HOME/.local/share/chezmoi`.
- **Template whitespace**: `{{-` and `-}}` trim whitespace. Both are needed on guards before shebangs (e.g., `{{- if ... -}}`) to avoid blank lines before `#!/bin/bash`.
- **Update phase ordering**: Scripts, externals, and files all run during the update phase in alphabetical order by target path. Scripts that depend on config files being placed first may need a second `chezmoi apply` on first run. Affects `.chezmoiexternal.toml` (fisher) and `dot_config/mise/config.toml` (mise install).
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

Note: the `nettleton/tap` tap is hardcoded in the brew install script (not in YAML) because it needs a custom git URL.

### External Downloads (`.chezmoiexternal.toml`)
Manages `fisher.fish` with weekly refresh via chezmoi's native external file support.

### Scripts (`.chezmoiscripts/`)
Organized by execution phase. Scripts are ordered alphabetically; `run_once_` and `run_onchange_` are interleaved by their numeric prefix.

**`00` Bootstrap** (`run_before_`)
- `00` — Install Homebrew, 1Password, 1Password CLI if missing; prompt for sign-in

**`00-*` System config** (`run_once_`)
- `00-00` — Convert git origin to SSH
- `00-01` — Configure sudo Touch ID
- `00-02` — Configure sshd (non-work machines only)

**`01` Install brew packages** (`run_onchange_`)
- Installs taps, brews, and casks from `.packages.brew.*`
- Personal packages gated on `.personalpackages`
- Re-runs automatically when `packages.yaml` brew lists change
- Auth via 1Password shell plugin (no hardcoded tokens)

**`02-*` Configure brew-installed packages** (`run_once_`)
- `02-00` — Fish shell (/etc/shells, chsh, fisher plugins, tide settings)
- `02-01` — Rust (rustup, CARGO_HOME)
- `02-02` — Go (GOPATH/GOBIN, /usr/local/netbin on work machines)
- `02-03` — mise install (Python, Node, npm/pip packages; `run_onchange_`, re-runs when mise config changes)
- `02-04` — Containers (podman machine, podman-mac-helper, docker-compose symlink)
- `02-05` — SwiftBar defaults
- `02-06` — Git auth (gh/glab login + SSH key upload to GitHub/GitLab)
- `02-08` — Tailscale defaults
- `02-09` — calBuddy (account login, sync service)
- `02-10` — Vale sync
- `02-11` — 1Password shell plugins (op plugin init brew)

**`03-*` Install packages via other managers** (`run_onchange_`)
- `03-02` — Go binaries from `.packages.go`

**`04-*` Install & configure apps** (mixed)
- `04-00` — Configure MailMate (`run_once_`; installed via `mailmate@beta` cask)
- `04-01` — Install Mac App Store apps (`run_onchange_`, from `.packages.mas.*`)

**`05-*` macOS system configuration** (`run_once_`)
- `05-00` — Setup other users
- `05-01` — macOS UI/UX and input (computer name, dark mode, trackpad, keyboard, locale)
- `05-02` — Energy saving (pmset, hibernation guarded by `is_laptop`)
- `05-03` — Screen (screenshots, screensaver password)
- `05-04` — Finder (views, sidebar, Library visibility)
- `05-05` — Dock, Mission Control, hot corners (all disabled), dock item removal
- `05-06` — App defaults (Safari, Mail, Spotlight, Terminal/iTerm, Chrome, Activity Monitor, TextEdit, etc.)
- `05-07` — Conditional app restarts (Dock/Finder unconditional, others prompted)

### Conditional Targeting
Templates use semantic boolean flags (`.is_work_machine`, `.is_personal_machine`, etc.) to conditionally include config per machine. The `.chezmoiignore` file also conditionally excludes files based on these flags.

### Secrets Management
All secrets are fetched from 1Password via `op read` or chezmoi's `onepasswordRead` template function. SSH public keys are stored as `.tmpl` files that resolve 1Password references at apply time. Homebrew auth uses the 1Password shell plugin (sourced in fish config).

### SSH Configuration (`private_dot_ssh/`)
SSH config and keys are templated per-machine. The 1Password SSH agent is used for all hosts (`IdentityAgent` points to the 1Password agent socket). Config uses `{{ define "1password" }}` template to deduplicate agent settings.

### Managed Configs (`dot_config/`)
Includes config for: fish shell, neovim (Lua-based with lazy.nvim), kitty, starship prompt, karabiner, gh/glab CLIs, SwiftBar plugins, fd, vale, zk, calBuddy, and others.
