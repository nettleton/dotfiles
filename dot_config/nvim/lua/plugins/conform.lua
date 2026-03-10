local conform_ok, conform = pcall(require, "conform")
if not conform_ok then
  vim.notify("require('conform') failed")
  return
end

conform.setup({
  formatters_by_ft = {
    c = { "clang-format" },
    cpp = { "clang-format" },
    fish = { "fish_indent" },
    go = { "goimports", "golines" },
    json = { "jq" },
    markdown = { "markdownlint" },
    proto = { "buf" },
    sh = { "shellharden" },
    sql = { "sql_formatter" },
    yaml = { "yamlfmt" },
    ["_"] = { "codespell" },
  },
  format_on_save = {
    timeout_ms = 3000,
    lsp_format = "fallback",
  },
})
