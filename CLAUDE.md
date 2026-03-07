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
- `run_once_` prefix → scripts that run once per content change (ordered by numeric prefix)

## Architecture

### Configuration Data (`.chezmoi.toml.tmpl`)
All template variables are defined here, prompted during `chezmoi init`. Key data sections:
- `.targetname` — identifies which machine (e.g., "starship", "nessie", or work hostnames)
- `.personalpackages` — boolean toggling personal vs work-only package sets
- `.work.*` — work domain, username, hostnames
- `.op.*` — 1Password item references for secrets (SSH keys, tokens)

### Run-Once Scripts (`run_once_*.sh.tmpl`)
Numbered for execution order:
- `00` — Convert git origin
- `01` — Install fish shell
- `02` — Configure fish
- `03` — Install Homebrew packages (taps, brews, casks; conditional personal packages)
- `04` — Configure packages (fish paths, Rust, Go, Python/pyenv, npm, podman, whisper.cpp, SwiftBar)
- `05` — Configure git/SSH keys on GitHub/GitLab (uses `gh` and `glab` CLIs)
- `10` — Configure sudo Touch ID
- `80` — Configure MailMate
- `90` — Configure macOS defaults
- `91` — Setup other users
- `95` — Manual macOS steps
- `98` — Install Mac App Store apps
- `99` — Install whalebrew containers

### Conditional Targeting
Templates use `.targetname` and `.chezmoi.username` to conditionally include config per machine. The `.chezmoiignore` file also conditionally excludes files based on target.

### Secrets Management
All secrets are fetched from 1Password via `op read` or chezmoi's `onepasswordRead` template function. SSH public keys are stored as `.tmpl` files that resolve 1Password references at apply time.

### SSH Configuration (`private_dot_ssh/`)
SSH config and keys are templated per-machine. The 1Password SSH agent is used for all hosts (`IdentityAgent` points to the 1Password agent socket).

### Managed Configs (`dot_config/`)
Includes config for: fish shell, neovim (Lua-based with lazy.nvim), kitty, starship prompt, karabiner, gh/glab CLIs, SwiftBar plugins, fd, vale, zk, and others.
