# dotfiles

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply nettleton
```

This single command installs chezmoi and applies the dotfiles. A bootstrap script automatically installs Homebrew, 1Password, and 1Password CLI if needed, prompting you to sign in before continuing.
