local codecompanion_ok, codecompanion = pcall(require, "codecompanion")
if not codecompanion_ok then
  vim.notify("require('codecompanion') failed")
  return
end

codecompanion.setup({
  adapters = {
    acp = {
      claude_code = {
        command = "claude-agent-acp",
      },
      codex = {
        command = "codex-acp",
      },
      amp = {
        command = "amp-acp",
      },
    },
  },
  strategies = {
    chat = {
      adapter = "acp",
      acp_agent = "claude_code",
    },
    inline = {
      adapter = "acp",
      acp_agent = "claude_code",
    },
  },
})
