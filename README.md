# dotfiles

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install --cask 1password 1password-cli chezmoi
op signin <DOMAIN> <EMAIL>
eval $(op signin <DOMAIN>)
chezmoi init --verbose --apply nettleton
```
