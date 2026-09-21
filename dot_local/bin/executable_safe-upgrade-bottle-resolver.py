#!/usr/bin/env python3
"""Local shim: prepend macOS 27 (Golden Gate) to safe-upgrade's bottle-SHA
resolver codename table upstream doesn't ship yet (0.4.3 stops at Tahoe).

Without this, the resolver silently downgrades the local side's tag while the
canonical side picks a different one, so every bottle-SHA check on this host
false-positives as `[BLOCKED] SHA mismatch` and the daily updater is locked
out of upgrading anything with a bottle.

Reached from bash via BREW_SAFE_BOTTLE_RESOLVER=<this file>. brew's env -i
allowlist (see /opt/homebrew/bin/brew) preserves only HOMEBREW_* and a small
fixed set, so brew-safe-upgrade / brew-safe-install MUST be invoked directly
(bypassing `brew safe-*`) for this env var to survive — see the export in
tests/wrapper/daily_update.sh and the fish `brew` shim in
dot_config/fish/functions/brew.fish.

Self-disabling: only patches when 27 is missing, so this stays a no-op once
upstream ships the codename. Check with:

    python3 -c "import sys; sys.path.insert(0, \\
      '/opt/homebrew/opt/safe-upgrade/libexec'); \\
      import bottle_resolver as r; print(r._CODENAMES)"

To retire once fixed upstream: delete this file, revert daily_update.sh's
brew-safe-* calls back to `brew safe-*`, drop the BREW_SAFE_BOTTLE_RESOLVER
exports in daily_update.sh and fish config, remove functions/brew.fish.
"""
import sys

sys.path.insert(0, "/opt/homebrew/opt/safe-upgrade/libexec")

import bottle_resolver as br  # noqa: E402

try:
    if not any(ver == 27 for ver, _ in br._CODENAMES):
        br._CODENAMES = [(27, "golden_gate")] + br._CODENAMES
        br._NAME_TO_VER = {name: ver for ver, name in br._CODENAMES}
except AttributeError:
    pass

sys.exit(br.main(sys.argv[1:]))
