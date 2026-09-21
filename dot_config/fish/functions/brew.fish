# Route interactive `brew safe-upgrade` / `brew safe-install` past brew's
# env -i filter (HOMEBREW_* allowlist strips BREW_SAFE_*) so
# BREW_SAFE_BOTTLE_RESOLVER (set in config.fish) reaches the script — picks
# up the Golden Gate _CODENAMES fix in the local wrapper. Everything else
# passes through to real brew. Retire together with the wrapper and the
# daily_update.sh export once upstream ships (27, "golden_gate").
function brew --wraps brew --description "safe-upgrade / safe-install shim for BREW_SAFE_BOTTLE_RESOLVER"
    switch "$argv[1]"
        case safe-upgrade
            command brew-safe-upgrade $argv[2..-1]
        case safe-install
            command brew-safe-install $argv[2..-1]
        case '*'
            command brew $argv
    end
end
