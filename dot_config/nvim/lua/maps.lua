-- This file is for custom key bindings for native vim functions
local opts = { noremap = true, silent = true }

--Remap space as leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Clear search highlights on escape
vim.keymap.set('n', '<ESC>', ':noh<CR><ESC>', opts)

-- Disable F1 bringing up the help doc every time
vim.keymap.set('i', '<F1>', '<ESC>', opts)
vim.keymap.set('n', '<F1>', '<ESC>', opts)
vim.keymap.set('v', '<F1>', '<ESC>', opts)

-- Visual --
-- Stay in indent mode
vim.keymap.set("v", "<", "<gv", opts)
vim.keymap.set("v", ">", ">gv", opts)

-- Move text up and down
vim.keymap.set("v", "<A-j>", ":m .+1<CR>==", opts)
vim.keymap.set("v", "<A-k>", ":m .-2<CR>==", opts)
vim.keymap.set("v", "p", '"_dP', opts)             -- repeated 'p' pastes the same thing

-- Visual Block --
-- Move text up and down
vim.keymap.set("x", "J", ":move '>+1<CR>gv-gv", opts)
vim.keymap.set("x", "K", ":move '<-2<CR>gv-gv", opts)
vim.keymap.set("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
vim.keymap.set("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

vim.keymap.set("n", "dd", function ()
	if vim.fn.getline(".") == "" then return '"_dd' end
	return "dd"
end, {expr = true})

-- REFERENCES
-- https://github.com/ayoisaiah/dotfiles/blob/master/private_dot_config/nvim/lua/maps.lua
-- https://github.com/LunarVim/Neovim-from-scratch
-- https://www.reddit.com/r/neovim/comments/1abd2cq/what_are_your_favorite_tricks_using_neovim/
-- https://nanotipsforvim.prose.sh/keeping-your-register-clean-from-dd
