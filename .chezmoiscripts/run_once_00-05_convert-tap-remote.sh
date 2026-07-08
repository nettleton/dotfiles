#!/usr/bin/env bash
# Flip the nettleton/tap clone from SSH to HTTPS. SSH routes through the
# 1Password agent, which pops an authorization prompt whenever `brew update`
# fetches the tap — including from the unattended daily brew-update job.
# HTTPS authenticates via the gh credential helper (see dot_gitconfig),
# prompt-free. Fresh machines tap over HTTPS from the start (packages.yaml
# no longer carries a git@ URL); this converts existing clones.
tap_dir="$(brew --repository nettleton/tap 2>/dev/null)"
if [ -d "$tap_dir" ] && git -C "$tap_dir" remote get-url origin 2>/dev/null | grep -q '^git@'; then
  git -C "$tap_dir" remote set-url origin https://github.com/nettleton/homebrew-tap.git
  echo "nettleton/tap: remote converted to HTTPS"
else
  echo "nettleton/tap: not cloned or already HTTPS, skipping"
fi
