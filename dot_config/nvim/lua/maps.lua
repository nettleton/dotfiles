-- This file is for custom key bindings for native vim functions
-- local g = vim.g
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

--Remap space as leader key
-- map("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Clear search highlights on escape
map('n', '<ESC>', ':noh<CR><ESC>', opts)

-- Disable F1 bringing up the help doc every time
map('i', '<F1>', '<ESC>', opts)
map('n', '<F1>', '<ESC>', opts)
map('v', '<F1>', '<ESC>', opts)

-- Copy and paste to the system clipboard
-- map('', '<leader>y', '"*y', opts)
-- map('', '<leader>d', '"*d', opts)
-- map('', '<leader>p', '"*p', opts)
-- map('', '<leader>P', '"*P', opts)
--
-- Normal
-- Better window navigation
-- map('n', '<leader>wh', '<C-w>h', opts)
-- map('n', '<leader>wj', '<C-w>j', opts)
-- map('n', '<leader>wk', '<C-w>k', opts)
-- map('n', '<leader>wl', '<C-w>l', opts)

-- Resize windows with arrows
-- map("n", "<C-Up>", ":resize -2<CR>", opts)
-- map("n", "<C-Down>", ":resize +2<CR>", opts)
-- map("n", "<C-Left>", ":vertical resize -2<CR>", opts)
-- map("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
-- map("n", "<leader>bj", ":bnext<CR>", opts)
-- map("n", "<leader>bk", ":bprevious<CR>", opts)

-- Insert --

-- Visual --
-- Stay in indent mode
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Move text up and down
map("v", "<A-j>", ":m .+1<CR>==", opts)
map("v", "<A-k>", ":m .-2<CR>==", opts)
map("v", "p", '"_dP', opts)             -- repeated 'p' pastes the same thing

-- Visual Block --
-- Move text up and down
map("x", "J", ":move '>+1<CR>gv-gv", opts)
map("x", "K", ":move '<-2<CR>gv-gv", opts)
map("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
map("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- REFERENCES
-- https://github.com/ayoisaiah/dotfiles/blob/master/private_dot_config/nvim/lua/maps.lua
-- https://github.com/LunarVim/Neovim-from-scratch
