#!/usr/bin/env bash
DEST=$(pwd)
cd .local/share/chezmoi
git remote set-url origin git@github.com:nettleton/dotfiles.git
cd "$DEST"
