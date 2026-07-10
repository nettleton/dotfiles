#!/usr/bin/env bash
# Activate the chezmoi source repo's tracked git hooks (.githooks/) so the
# pre-commit leak scan runs on every machine. core.hooksPath is per-clone local
# config (not tracked), so it must be set once per machine — here.
cd "$HOME/.local/share/chezmoi" && git config core.hooksPath .githooks
