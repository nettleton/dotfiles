#!/bin/bash
# PreToolUse hook: reject nvim/kitty commands that target the wrong session.
# Receives tool call JSON on stdin. Exit 0 = allow, exit 2 = block.

input=$(cat)
tool=$(echo "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)

if [ "$tool" != "Bash" ]; then
    exit 0
fi

cmd=$(echo "$input" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)

# Validate nvim --server commands target this session's socket
if echo "$cmd" | grep -q 'nvim.*--server'; then
    if [ -z "$CODING_SESSION_NVIM_SOCK" ]; then
        echo '{"decision":"block","reason":"No coding session active (CODING_SESSION_NVIM_SOCK not set)"}'
        exit 2
    fi
    if ! echo "$cmd" | grep -qF "$CODING_SESSION_NVIM_SOCK"; then
        echo '{"decision":"block","reason":"nvim --server target does not match this session socket ('"$CODING_SESSION_NVIM_SOCK"')"}'
        exit 2
    fi
fi

# Validate kitty @ commands that use --match id: target this session's terminal
if echo "$cmd" | grep -q 'kitty @.*--match id:'; then
    if [ -z "$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID" ]; then
        echo '{"decision":"block","reason":"No coding session active (CODING_SESSION_TERMINAL_KITTY_WINDOW_ID not set)"}'
        exit 2
    fi
    if ! echo "$cmd" | grep -qF "id:$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID"; then
        echo '{"decision":"block","reason":"kitty window target does not match this session terminal ('"$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID"')"}'
        exit 2
    fi
fi

exit 0
