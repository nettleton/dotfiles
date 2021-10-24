-- support front matter
-- enabling front matter makes hyperlinks in the URL unreachable via 'gx'
-- vim.g.vim_markdown_frontmatter = 1  -- for YAML format

-- MATLAB syntax highlighting
-- vim.g.vim_markdown_fenced_languages = "['matlab=octave']"

-- disable header folding
vim.g.vim_markdown_folding_disabled = 1

-- do not require .md extensions for Markdown links
vim.g.vim_markdown_no_extensions_in_markdown = 1

-- auto-write when following link
vim.g.vim_markdown_autowrite = 1

-- open links in new tab
vim.g.vim_markdown_edit_url_in = 'tab'
