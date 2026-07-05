local lint_ok, lint = pcall(require, "lint")
if not lint_ok then
  vim.notify("require('lint') failed")
  return
end

lint.linters_by_ft = {
  fish = { "fish" },
  -- go: handled by the golangci_lint_ls LSP (golangci-lint, incl. staticcheck)
  -- and gopls (staticcheck + analyses); nvim-lint would just duplicate them.
  lua = { "luacheck" },
  markdown = { "markdownlint", "vale" },
  python = { "pylint" },
  sh = { "shellcheck" },
  yaml = { "yamllint" },
}

-- Lint on save and when entering a buffer
vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
  callback = function()
    lint.try_lint()
  end,
})
