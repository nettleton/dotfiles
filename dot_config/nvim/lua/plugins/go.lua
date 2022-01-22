-- ALIASES
local exec = vim.api.nvim_exec

-- CONFIG
require('go').setup()

require("nvim-dap-virtual-text").setup()

require('lspconfig').gopls.setup{}

-- 1. format on save
-- 2. import on save
-- Run gofmt + goimport on save
vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').goimport() ]], false)

-- REFERENCES
-- https://github.com/ray-x/go.nvim
--   the linked treesitter config is actually https://github.com/ray-x/dotfiles/blob/zprezto-plug/lua/treesitter.lua
-- https://github.com/ray-x/navigator.lua/blob/master/lua/navigator/lspclient/clients.lua
