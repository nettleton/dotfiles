# Completions for code-session (cs). The `cs` abbreviation (abbr in
# config.fish) expands to `code-session` on space, so argument completion
# runs against this command name.
#
# Managed by chezmoi: dot_config/fish/completions/code-session.fish ->
# ~/.config/fish/completions/code-session.fish

function __cs_complete_slugs --description "Managed-worktree branch slugs for the repo at PWD"
    set -l root "$HOME/.local/share/code-session/worktrees"
    for line in (git worktree list --porcelain 2>/dev/null)
        string match -rq '^worktree (?<p>.*)' -- $line; or continue
        string match -q -- "$root/*" "$p"; or continue
        set -l b (git -C "$p" rev-parse --abbrev-ref HEAD 2>/dev/null)
        test -n "$b"; and printf '%s\t%s\n' "$b" "worktree"
    end
end

# No bare file completion; directories are added only where they make sense.
complete -c code-session -f

# First token: a subcommand, or a project directory for a plain session.
complete -c code-session -n __fish_use_subcommand -a list -d 'List this repo'\''s managed worktrees'
complete -c code-session -n __fish_use_subcommand -a rm -d 'Remove a managed worktree'
complete -c code-session -n __fish_use_subcommand -a '(__fish_complete_directories)'

# -w/--worktree <slug>: suggest existing slugs to reuse; a fresh slug is fine too.
complete -c code-session -n __fish_use_subcommand -s w -l worktree -x \
    -a '(__cs_complete_slugs)' -d 'Create/reuse a worktree on <slug>'

# rm [slug|.|path] [--force]: existing slugs, `.` for the current worktree,
# directory paths, and the --force flag.
complete -c code-session -n '__fish_seen_subcommand_from rm --rm' -a '(__cs_complete_slugs)' -d worktree
complete -c code-session -n '__fish_seen_subcommand_from rm --rm' -a . -d 'This worktree'
complete -c code-session -n '__fish_seen_subcommand_from rm --rm' -a '(__fish_complete_directories)'
complete -c code-session -n '__fish_seen_subcommand_from rm --rm' -s f -l force -d 'Remove even with uncommitted changes'
