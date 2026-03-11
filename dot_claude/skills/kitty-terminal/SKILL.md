---
name: kitty-terminal
description: Send commands to the terminal pane in a coding session via kitty remote control. Use when you need to run shell commands in the terminal pane, check command output, or interact with the terminal window alongside the coding agent.
user-invocable: true
allowed-tools: Bash(kitty @*), Bash(python3 -c *)
hooks:
  PreToolUse:
    - matcher: "Bash"
      command: "~/.claude/skills/coding-session/hooks/validate-session-target.sh"
---

# Kitty Terminal Pane (Coding Session)

When running inside a coding session, `$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID`
identifies the terminal pane. Use kitty's remote control API to interact with it.

## Prerequisites

Verify the terminal window ID is available:

```bash
echo "$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID"
```

If empty, there is no coding session terminal pane available.

## Sending Commands

Send text to the terminal pane (include `\n` to execute):

```bash
kitty @ send-text --match id:$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID "ls -la\n"
```

Send multiple commands sequentially:

```bash
kitty @ send-text --match id:$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID "cd src && make build\n"
```

## Checking Terminal State

Get the terminal pane's current working directory and foreground process:

```bash
kitty @ ls | python3 -c "
import json, sys
data = json.load(sys.stdin)
wid = $CODING_SESSION_TERMINAL_KITTY_WINDOW_ID
for osw in data:
    for tab in osw['tabs']:
        for w in tab['windows']:
            if w['id'] == wid:
                print('cwd:', w['cwd'])
                procs = [p['cmdline'] for p in w.get('foreground_processes', [])]
                print('procs:', procs)
"
```

## Getting Terminal Output

Retrieve the last N lines of scrollback from the terminal pane:

```bash
kitty @ get-text --match id:$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID --extent last_cmd_output
```

Other `--extent` options:
- `screen` — visible screen content
- `all` — full scrollback buffer (can be large)
- `last_cmd_output` — output from the last command (requires shell integration)

## Focus Control

Focus the terminal pane (e.g., before sending interactive commands):

```bash
kitty @ focus-window --match id:$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID
```

## Safety

- **Never** send destructive commands (`rm -rf`, `git reset --hard`, etc.)
  without explicit user confirmation.
- Be aware that `send-text` simulates typing — if the terminal has a running
  process (not a shell prompt), the text goes to that process's stdin.
- Check the foreground process before sending commands to avoid unexpected
  behavior.
