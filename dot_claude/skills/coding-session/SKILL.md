---
name: coding-session
description: Manage and understand the kitty coding session layout. Use when the user asks about the coding session, its panes, or how to interact with nvim or the terminal from within the session.
disable-model-invocation: false
---

# Coding Session Layout

The `code-session` fish function transforms the current kitty tab into a
three-pane coding layout:

```
+---------------------+---------------------+
|                     |                     |
|                     |       nvim          |
|   coding agent      |     (top right)     |
|   (left, full       |                     |
|    height)          +---------------------+
|                     |                     |
|                     |     terminal        |
|                     |   (bottom right)    |
+---------------------+---------------------+
```

## Usage

```fish
code-session                      # current dir, claude agent
code-session ~/project            # specific dir, claude agent
code-session ~/project amp        # specific dir, amp agent
```

## Environment Variables

When running inside a coding session, these variables are exported in the
agent's environment:

| Variable | Value | Purpose |
|---|---|---|
| `CODING_SESSION_NVIM_SOCK` | `/tmp/nvim-<os_window_id>-<tab_id>.sock` | nvim RPC socket path |
| `CODING_SESSION_TERMINAL_KITTY_WINDOW_ID` | kitty window ID (integer) | Target for `kitty @ send-text` |

Check if you're in a coding session:

```bash
echo "$CODING_SESSION_NVIM_SOCK"
```

If empty, there is no coding session active.

## Interacting with Panes

- **To send commands to nvim**: Use the `neovim-rpc` skill patterns with
  `$CODING_SESSION_NVIM_SOCK` as the server address.
- **To run commands in the terminal pane**: Use the `kitty-terminal` skill
  patterns with `$CODING_SESSION_TERMINAL_KITTY_WINDOW_ID`.

## File Requests

When the user asks to "open", "show me", or "view" a file, **open it in the
coding session's nvim** — do not display file contents in the chat. Use the
`neovim-rpc` skill to send the file to nvim via `--remote`.

## Opening a Prompt in nvim

To open a command prompt in the coding session's nvim (e.g., for the user to
type a command or search):

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-send ':<Space>'
```

To pre-fill a specific Ex command for the user to confirm:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-send ':edit '
```

## Tab Title

The tab is titled "Coding Session: <dirname>". This is set statically when the
session is created.

## Multiple Sessions

Multiple coding sessions can run simultaneously in different kitty tabs. Each
has unique IDs derived from the kitty OS window and tab IDs, so nvim sockets
and terminal window IDs never collide.
