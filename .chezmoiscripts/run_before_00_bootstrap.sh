#!/usr/bin/env bash

# Bootstrap script: installs Homebrew, 1Password, 1Password CLI, and
# safe-upgrade (the security gate every later brew install/upgrade goes
# through — it must exist before the package installer runs).
# This is a non-template file — it cannot use onepasswordRead since
# it may be installing 1Password for the first time.

set -e

# Install Homebrew if not present
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for the rest of this script
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "Homebrew already installed, skipping"
fi

# Install 1Password if not present
if [ ! -d "/Applications/1Password.app" ]; then
  echo "Installing 1Password..."
  brew install --cask 1password
else
  echo "1Password already installed, skipping"
fi

# Install 1Password CLI if not present
if ! command -v op &>/dev/null; then
  echo "Installing 1Password CLI..."
  brew tap 1password/tap 2>/dev/null || true
  brew install --cask 1password/tap/1password-cli
else
  echo "1Password CLI already installed, skipping"
fi

# Install safe-upgrade (security-gated brew install/upgrade) if not present.
# Same pattern as 1Password: bootstrap installs it early (the gate must exist
# before the gated package installer runs), while packages.yaml still declares
# it (prune-safe, covered by the package audits). The explicit `brew trust`
# is needed only in the fresh-machine window: run_before scripts execute
# before chezmoi places the managed ~/.homebrew/trust.json.
if ! command -v brew-safe-install &>/dev/null; then
  echo "Installing safe-upgrade..."
  brew tap sharkyger/tap 2>/dev/null || true
  brew trust --tap sharkyger/tap
  brew install sharkyger/tap/safe-upgrade
else
  echo "safe-upgrade already installed, skipping"
fi

# Verify 1Password CLI is signed in
if ! op account list &>/dev/null || [ -z "$(op account list 2>/dev/null)" ]; then
  echo ""
  echo "============================================================"
  echo "  1Password CLI is not signed in."
  echo "  Open 1Password.app, sign in, then enable CLI integration:"
  echo "    Settings > Developer > Command-Line Interface (CLI)"
  echo "============================================================"
  echo ""
  read -p "Press Enter once you've signed in to 1Password..." -r
fi
