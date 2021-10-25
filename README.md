# dotfiles

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install --cask 1password 1password-cli
op signin <DOMAIN> <EMAIL>
eval $(op signin <DOMAIN>)
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply nettleton
```
