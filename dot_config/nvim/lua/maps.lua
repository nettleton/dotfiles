-- This file is for custom key bindings for native vim functions
local g = vim.g
local map = vim.api.nvim_set_keymap

g.mapleader = " " -- Change leader key from \ to ,

-- Disable F1 bringing up the help doc every time
map('i', '<F1>', '<ESC>', { noremap = true })
map('n', '<F1>', '<ESC>', { noremap = true })
map('v', '<F1>', '<ESC>', { noremap = true })

map('i', 'jj', '<ESC>', { noremap = true })

-- Copy and paste to the system clipboard
map('', '<leader>y', '"*y', { noremap = true})
map('', '<leader>d', '"*d', { noremap = true})
map('', '<leader>p', '"*p', { noremap = true})
map('', '<leader>P', '"*P', { noremap = true})

map('n', '<C-h>', '<C-w>h', { noremap = true})
map('n', '<C-l>', '<C-w>l', { noremap = true})

-- REFERENCES
-- https://github.com/ayoisaiah/dotfiles/blob/master/private_dot_config/nvim/lua/maps.lua