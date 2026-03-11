---
name: chezmoi
description: Manage dotfiles and packages with chezmoi. Use when working with dotfiles, config files outside of project directories, chezmoi templates, brew/mise packages, machine-specific configuration, or when the user mentions chezmoi, dotfiles, packages, or configuration management. Also triggers when the user wants to install, remove, or update brew packages, casks, or mise tools.
allowed-tools: Read, Edit, Write, Glob, Grep, Bash(chezmoi *)
---

# Chezmoi Dotfiles Management

This repo is a chezmoi dotfiles repository at `~/.local/share/chezmoi/`.
See `CLAUDE.md` in the repo root for full architecture documentation.

## Critical Rules

1. **Always check for templates first** before editing any config file.
   If a `.tmpl` version exists, edit that — never the generated file.
2. **Never use `chezmoi add` on a templated file** — it strips template logic.
   Copy directly to the source instead.
3. **Never call `chezmoi` from within a chezmoi script** — chezmoi holds a
   lock during apply and it will deadlock.
4. **Preview before applying**: `chezmoi diff` or `chezmoi apply --dry-run`.
5. **Implement changes directly** — don't just suggest them.
6. **Always add config to chezmoi** — when configuring a new app, tool, or
   service, the config must go into the chezmoi source so it's reproducible
   across machines. Never leave config only on the local machine.

## Shell Consistency

Fish is the primary shell, but bash (`dot_bashrc.mine.tmpl`) and zsh
(`dot_zshrc`) configs must stay consistent for shared concerns:

- **PATH setup**: all three shells should have `/opt/homebrew/bin`
- **Shell plugins**: 1Password `plugins.sh` sourced in all three
- **Aliases/abbreviations**: common aliases (cat→bat, vi→nvim, l→eza) in all three
- **Tool activation**: `mise activate` in all three
- **Prompt**: `starship init` in bash and zsh

When adding something to fish config, check if bash/zsh need the equivalent.

## Chezmoi-First Principle

When the user asks to configure something (a new app, shell setting, tool,
environment variable, etc.), **always put the configuration into chezmoi**:

- **App config files** → add to `dot_config/` (or appropriate chezmoi path)
- **New packages** → add to `.chezmoidata/packages.yaml` (not `brew install`)
- **New npm/pip tools** → add to `dot_config/mise/config.toml` (not `npm -g`)
- **Shell config** → edit `dot_config/fish/config.fish.tmpl` (not `~/.config/fish/config.fish`)
- **New scripts** → add to `.chezmoiscripts/` with proper `run_once_`/`run_onchange_` prefix
- **Environment variables** → add to the appropriate shell config template
- **Machine-specific config** → use template conditionals or `.chezmoiignore`

The goal: `chezmoi apply` on a fresh machine should fully reproduce the
user's environment. If a change wouldn't survive `chezmoi apply`, it's wrong.

Never run `brew install`, `npm install -g`, `pip install`, or similar commands
directly. Always update the declarative config and let `chezmoi apply` handle
installation.

## Prefix Mappings

| Actual path | Chezmoi source |
|---|---|
| `~/.foo` | `dot_foo` |
| `~/.config/bar` | `dot_config/bar` |
| `~/.ssh/config` | `private_dot_ssh/config` |
| Sensitive files | `private_` prefix (0600 permissions) |
| Executables | `executable_` prefix |
| Templates | `.tmpl` suffix |

Source directory: `~/.local/share/chezmoi/`

## Template Variables

All variables defined in `.chezmoi.toml.tmpl`. Key flags:

```
.targetname              # machine name (starship, nessie, work hostnames)
.is_work_machine         # semantic boolean
.is_personal_machine     # semantic boolean
.is_wife_machine         # semantic boolean
.is_child_machine        # semantic boolean
.is_laptop               # semantic boolean
.personalpackages        # true on non-work machines
.work.user, .work.domain # work identity
.packages.*              # package lists from .chezmoidata/packages.yaml
```

Use `chezmoi data` to see all current values.
Use `chezmoi execute-template '{{ .is_work_machine }}'` to test snippets.

## Template Whitespace

`{{-` trims leading whitespace, `-}}` trims trailing. Both are needed on
guards before shebangs to avoid blank lines:

```
{{- if (eq .chezmoi.os "darwin") -}}
#!/bin/bash
```

## Adding/Editing Config Files

### Workflow

1. **Find the source**: `chezmoi source-path ~/.config/foo/bar`
2. **Check if templated**: look for `.tmpl` suffix in source
3. **Edit the source file** (in `~/.local/share/chezmoi/`)
4. **Preview**: `chezmoi diff`
5. **Apply**: `chezmoi apply` (or `chezmoi apply ~/.config/foo/bar` for one file)

### Adding a New File

```bash
chezmoi add ~/.config/foo/bar        # Add as static file
chezmoi add --template ~/.config/foo # Add as template (if it needs variables)
```

### Machine-Specific Conditionals

```
{{ if .is_work_machine -}}
# work-only config
{{- end }}

{{ if .personalpackages -}}
# personal machine only
{{- end }}
```

For excluding entire files by machine type, add entries to `.chezmoiignore`.

## Managing Brew Packages

Packages are declared in `.chezmoidata/packages.yaml` under `.packages.brew`.
The brew install script (`run_onchange_01_install-brew-packages.sh.tmpl`)
re-runs automatically whenever the rendered package list changes.

### Package lists

| YAML key | Description | Gated by |
|---|---|---|
| `packages.brew.taps` | Homebrew taps | — |
| `packages.brew.brews` | CLI tools (all machines) | — |
| `packages.brew.casks` | GUI apps (all machines) | — |
| `packages.brew.personal_brews` | CLI tools (personal only) | `.personalpackages` |
| `packages.brew.personal_casks` | GUI apps (personal only) | `.personalpackages` |

### To install a new brew package

1. Edit `.chezmoidata/packages.yaml`
2. Add the package name to the appropriate list (alphabetically sorted)
3. Run `chezmoi apply` — the `run_onchange_` script auto-triggers

```bash
# Example: add a new CLI tool
# Edit .chezmoidata/packages.yaml, add under packages.brew.brews:
#   - ripgrep
# Then:
chezmoi apply
```

### To install a new cask

Same as above but under `packages.brew.casks` or `packages.brew.personal_casks`.

### Private tap

`nettleton/tap` is hardcoded in the brew script (not in YAML) because it uses
a custom SSH git URL. Auth token is injected via `op read`. To add a formula
from this tap, add it as `"nettleton/tap/formulaname"` in the brews list.

## Managing Mise Tools

Tool versions are in `dot_config/mise/config.toml`. The mise install script
(`dot_config/mise/run_onchange_configure-mise.fish.tmpl`) re-runs when the
config changes.

```toml
# dot_config/mise/config.toml
[tools]
java = "corretto-21"
python = "latest"
node = "latest"
pipx = "latest"
"npm:neovim" = "latest"
"npm:npm" = "latest"
```

To add a new tool or npm package, edit this file and run `chezmoi apply`.

## Managing Fisher Plugins

Fisher plugins are listed in `.chezmoidata/packages.yaml` under
`.packages.fisher`. The fish config script installs them during
`02-00_configure-fish`.

## Managing Go Binaries

Go packages are in `.chezmoidata/packages.yaml` under `.packages.go`.
The install script (`run_onchange_03-02_install-go.fish.tmpl`) re-runs
when the list changes.

## Managing Mac App Store Apps

MAS apps are in `.chezmoidata/packages.yaml` under `.packages.mas.apps`
(with `name` and `id`). The install script
(`run_onchange_04-01_install-mas-apps.sh.tmpl`) re-runs when the list changes.

## Conflict Resolution

When local drift exists (files modified outside chezmoi):

1. **Check status**: `chezmoi status` (shows drift between source and target)
2. **Capture local changes**: copy modified target files back to source
3. **Preview**: `chezmoi diff`
4. **Apply**: `chezmoi apply`

Do NOT use `chezmoi add` on templated files — copy directly instead:

```bash
# Wrong (strips template):
chezmoi add ~/.config/foo

# Right (preserves template):
cp ~/.config/foo ~/.local/share/chezmoi/dot_config/foo.tmpl
```

## Script Taxonomy

Scripts in `.chezmoiscripts/` follow a numeric prefix taxonomy that controls
execution order (alphabetical by target path):

| Prefix | Phase | Purpose |
|---|---|---|
| `00` | Bootstrap | Install prerequisites (Homebrew, 1Password), system config (sudo, sshd, git origin, op plugins) |
| `01` | Brew packages | `run_onchange_` — install taps, brews, casks from packages.yaml |
| `02` | Configure tools | `run_once_` — configure tools installed by brew (fish, rust, go, mise, containers, git auth, etc.) |
| `03` | Other package managers | `run_onchange_` — install packages via go, pip, etc. |
| `04` | Apps | Configure/install apps (MailMate, Mac App Store) |
| `05` | macOS defaults | System preferences (UI, energy, screen, Finder, Dock, app defaults, restarts) |

### Script design principles

- **One script per tool/concern.** Each script should configure exactly one
  tool or service. Do not create catch-all scripts that configure multiple
  unrelated things. Example: `02-01_configure-rust` only sets up Rust,
  `02-02_configure-go` only sets up Go.
- **Name scripts after what they configure**, not what they do generically.
  Good: `02-06_configure-git-auth`. Bad: `02-06_setup-stuff`.
- **Use the right prefix type**: `run_onchange_` for package installs (re-run
  when lists change), `run_once_` for one-time configuration, `run_after_`
  for every-apply fixups.
- **When adding a new tool**, create a new script rather than appending to an
  existing one. Pick the appropriate numeric prefix for the phase.

## Idempotency

All chezmoi scripts must be safe to run multiple times. `chezmoi apply` can
re-run at any time, and scripts must not fail or produce side effects on
repeated execution.

### Script types and re-run behavior

| Prefix | Re-runs when | Idempotency requirement |
|---|---|---|
| `run_once_` | Rendered content changes (hash-based) | Must handle already-configured state |
| `run_onchange_` | Rendered content changes (hash-based) | Must handle already-installed packages |
| `run_before_` | Every apply | Must be fast and safe to repeat |
| `run_after_` | Every apply | Must be fast and safe to repeat |

### Patterns for idempotent scripts

- **Package installs**: `brew bundle` is inherently idempotent (skips installed)
- **Config changes**: Check before modifying (`grep -q` before appending)
- **Service setup**: Guard with existence checks (`if not test -d`, `command -v`)
- **File operations**: Use `mkdir -p`, `ln -sfn` (safe to repeat)
- **Destructive ops**: Always guard (`[ -f "$file" ] && chmod ...`)

### run_after_ scripts

These run on every `chezmoi apply`. Keep them fast and guard every operation:

```bash
#!/bin/bash
[ -f "$HOME/.netrc" ] && chmod 400 "$HOME/.netrc"
exit 0  # Always succeed (avoid blocking apply)
```

### Content hash triggers

`run_onchange_` scripts embed content hashes in comments to trigger re-runs
when data changes:

```
# packages hash: {{ include ".chezmoidata/packages.yaml" | sha256sum }}
# mise config hash: {{ include "dot_config/mise/config.toml" | sha256sum }}
```

When the referenced file changes, the rendered script content changes, and
chezmoi re-runs it.

## Update Phase Ordering

Scripts, externals, and files run alphabetically by **target path** during
apply. This matters for dependencies:

- `dot_config/mise/config.toml` (placed as `.config/mise/config.toml`)
- `dot_config/mise/run_onchange_configure-mise.fish.tmpl` (runs as
  `.config/mise/configure-mise.fish` — sorts after config.toml)

If a script depends on a config file, ensure the script's target path sorts
after the config file's target path.

## Secrets

All secrets come from 1Password:

- `op read "op://vault/item/field"` in scripts
- `{{ onepasswordRead "op://vault/item/field" }}` in templates
- Never hardcode tokens or passwords
- All SSH keys (both public and private keys) also come from 1Password's SSH agent

## Other Sensitive Information

- As this is a public repo, never check in work names, domains, URLs directly
- chezmoi data contains fields like .workcompanyname and .work.domain to obfuscate this

## Common Mistakes

| Mistake | Fix |
|---|---|
| Edit generated file instead of source | Always find source first with `chezmoi source-path` |
| `chezmoi add` on a template | Copy directly to source |
| Call `chezmoi` inside a chezmoi script | Use hardcoded paths instead |
| Package not in alphabetical order | Sort the YAML list |
| Missing `{{-` before shebang | Add whitespace trimming to avoid blank lines |
| Script runs before its config is placed | Rename so target path sorts after config |
