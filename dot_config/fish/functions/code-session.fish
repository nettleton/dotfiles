function code-session -d "Transform current kitty tab into a coding session layout"
    set -l dir (test -n "$argv[1]" && echo $argv[1] || pwd)
    set -l agent $argv[2]

    set dir (realpath "$dir")
    if not test -d "$dir"
        echo "code-session: $dir is not a directory"
        return 1
    end

    if test -z "$agent"
        set agent claude
    end

    set -l dirname (basename "$dir")

    # Get current OS window and tab IDs from kitty
    set -l my_window_id $KITTY_WINDOW_ID
    set -l tab_info (kitty @ ls --match id:$my_window_id 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for osw in data:
    for tab in osw['tabs']:
        for w in tab['windows']:
            if w['id'] == $my_window_id:
                print(osw['id'])
                print(tab['id'])
                sys.exit(0)
" 2>/dev/null)

    if test (count $tab_info) -ne 2
        echo "code-session: failed to get kitty tab info"
        return 1
    end

    set -l os_window_id $tab_info[1]
    set -l tab_id $tab_info[2]
    set -l nvim_sock "/tmp/nvim-$os_window_id-$tab_id.sock"

    # Set layout to splits
    kitty @ goto-layout --match id:$my_window_id splits

    # Launch nvim (right side) via login shell so mise/JAVA_HOME are available
    set -l nvim_window_id (kitty @ launch --location=vsplit --cwd="$dir" fish -l -c "nvim --listen $nvim_sock")

    # Launch terminal (below nvim) — hsplit the now-focused nvim window, then refocus agent
    set -l terminal_window_id (kitty @ launch --location=hsplit --cwd="$dir")
    kitty @ focus-window --match id:$my_window_id

    # Set tab title
    kitty @ set-tab-title --match id:$my_window_id "Coding Session: $dirname"

    # Export session variables into this shell before exec
    set -gx CODING_SESSION_NVIM_SOCK "$nvim_sock"
    set -gx CODING_SESSION_TERMINAL_KITTY_WINDOW_ID "$terminal_window_id"

    # Replace this shell with the agent
    cd "$dir"
    exec $agent
end
