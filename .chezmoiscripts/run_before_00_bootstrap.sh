#!/usr/bin/env bash

# Bootstrap script: installs Homebrew, 1Password, and 1Password CLI
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
