-- support front matter
-- enabling front matter makes hyperlinks in the URL unreachable via 'gx'
-- vim.g.vim_markdown_frontmatter = 1  -- for YAML format

-- disable auto insertion of bullets (handled by gaoDean/autolist.nvim)
vim.g.vim_markdown_auto_insert_bullets = 0

-- MATLAB syntax highlighting
vim.g.vim_markdown_fenced_languages = { 'matlab=octave' }

-- disable header folding
vim.g.vim_markdown_folding_disabled = 1

-- do not require .md extensions for Markdown links
vim.g.vim_markdown_no_extensions_in_markdown = 1

-- auto-write when following link
vim.g.vim_markdown_autowrite = 1

-- open links in new tab
vim.g.vim_markdown_edit_url_in = 'tab'

-- follow named anchors
vim.g.vim_markdown_follow_anchor = 1

-- set conceallevel for markdown files
vim.api.nvim_create_autocmd({"FileType"}, {
  pattern = {"markdown"},
  command = "lua vim.opt.conceallevel = 2",
})

-- Extract reminders from markdown files
vim.api.nvim_create_user_command("ExtractReminders", function()
  local filenameExpanded = vim.fn.expand('%:p')
  if string.find(filenameExpanded, "notes") then
    vim.fn.system("extractReminders \"" .. filenameExpanded .. "\"")
    vim.api.nvim_command("checktime")
  end
end, { nargs = 0 })

-- Map ExtractReminders to file write events
vim.api.nvim_create_autocmd({"BufWritePost"}, {
  pattern = {"*.md"},
  command = "lua vim.api.nvim_command('ExtractReminders')"
})
