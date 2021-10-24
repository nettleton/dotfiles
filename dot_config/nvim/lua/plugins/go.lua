-- ALIASES
local exec = vim.api.nvim_exec

-- CONFIG
require('go').setup()

-- 1. format on save
-- 2. import on save
-- TODO: This erases valid code even though :lua require... doesn't
-- exec([[
-- autocmd BufWritePre *.go :silent! lua require('go.format').gofmt()
-- autocmd BufWritePre *.go :silent! lua require('go.format').goimport()
-- ]], false)


-- REFERENCES
-- https://github.com/ray-x/go.nvim
--   the linked treesitter config is actually https://github.com/ray-x/dotfiles/blob/zprezto-plug/lua/treesitter.lua
