---
name: neovim-rpc
description: Interact with the neovim instance in a coding session via RPC. Use when you need to open files in nvim, query buffer state, send commands, refresh LSP diagnostics, or inspect neovim state. Triggers when the user asks to open a file in the editor, check LSP status, or interact with neovim.
user-invocable: true
allowed-tools: Bash(nvim --server *)
hooks:
  PreToolUse:
    - matcher: "Bash"
      command: "~/.claude/skills/coding-session/hooks/validate-session-target.sh"
---

# Neovim RPC (Coding Session)

When running inside a coding session, `$CODING_SESSION_NVIM_SOCK` points to
the nvim instance's Unix socket. This gives full access to Neovim's RPC API.

## Prerequisites

Verify the socket is available before sending any commands:

```bash
echo "$CODING_SESSION_NVIM_SOCK"
```

If empty, there is no coding session nvim instance available.

## Evaluating Expressions

Use `--remote-expr` to evaluate a Vimscript expression and get the result:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'v:version'
```

For Lua expressions, wrap in `luaeval()`:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.api.nvim_buf_get_name(0)")'
```

For multi-statement Lua returning a value, use an IIFE:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("(function() local x = vim.api.nvim_get_current_win(); return vim.api.nvim_win_get_number(x) end)()")'
```

### Returning Tables/Lists

Encode complex data as JSON:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.json.encode(vim.api.nvim_list_bufs())")'
```

## Sending Commands

Use `--remote-send` to send keystrokes (as if the user typed them):

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-send ':echo "hello"<CR>'
```

Note: `--remote-send` does not return output. Use `--remote-expr` when you need
a return value.

## Opening Files

Open a file in the running nvim instance:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote file.txt
```

Open files in new tabs:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-tab file1.txt file2.txt
```

## Executing Lua Side Effects

Run Lua that performs side effects (no return value needed):

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'execute("lua vim.notify(\"Hello from Claude\")")'
```

## Common Patterns

```bash
# Current buffer path
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.api.nvim_buf_get_name(0)")'

# List all buffer paths (JSON)
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.json.encode(vim.tbl_map(function(b) return vim.api.nvim_buf_get_name(b) end, vim.api.nvim_list_bufs()))")'

# Current working directory
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.fn.getcwd()")'

# Current cursor position [row, col]
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.json.encode(vim.api.nvim_win_get_cursor(0))")'

# Check attached LSP clients
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'luaeval("vim.json.encode(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients({bufnr = 0})))")'
```

## Stale LSP Diagnostics

When files are edited externally (e.g., by Claude), nvim's LSP diagnostics
become stale. To refresh:

**Reload buffer and save** (forces LSP re-analysis):

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'execute("lua vim.api.nvim_buf_call(BUFNR, function() vim.cmd(\"edit! | write\") end)")'
```

Replace `BUFNR` with the actual buffer number, or use `0` for the current
buffer.

**Restart LSP** (if reload isn't enough):

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote-expr 'execute("LspRestart")'
```

Wait ~10 seconds after restart for the LSP to re-index before querying.

## File Requests

When the user asks to "open", "show me", or "view" a file or its contents,
**always open it in the coding session's nvim instance** using `--remote`:

```bash
nvim --server "$CODING_SESSION_NVIM_SOCK" --remote file.txt
```

Do NOT read the file contents and display them in the chat. The user expects
files to appear in their editor.

## Safety

- **Never** send `:q`, `:qa`, `:bdelete`, or other destructive commands without
  explicit user confirmation.
- **Never** modify buffer contents via RPC without asking first.
- Prefer `--remote-expr` (read-only) over `--remote-send` (simulates typing).
