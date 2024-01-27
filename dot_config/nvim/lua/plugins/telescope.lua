-- local map = vim.api.nvim_set_keymap

local telescope_ok, telescope = pcall(require, "telescope")
if not telescope_ok then
  vim.notify("require('telescope') failed")
  return
end
local actions_ok, actions = pcall(require, "telescope.actions")
if not actions_ok then
  vim.notify("require('telescope.actions') failed")
  return
end

telescope.setup{
  defaults = {
    vimgrep_arguments = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--smart-case',
      '--ignore-file',
      '~/.vimignore'
    },
    mappings = {
      i = {
        ["<esc>"] = actions.close,
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
      },
    },
  },
  pickers = {
    buffers = {
      ignore_current_buffer = true,
      sort_lastused = true,
    },
  },
  extensions = {
    fzf = {},
    repo = {
      search_dirs = {
        "~/sandbox"
      }
    },
    file_browser = {
      files = false,
    },
    lazy = {},
  },
}

telescope.load_extension('fzf')
telescope.load_extension('repo')
telescope.load_extension('luasnip')
telescope.load_extension('file_browser')
telescope.load_extension('lazy')
telescope.load_extension('dap')

-- map('n', '<leader>f', '<cmd>lua require("telescope.builtin").find_files({ hidden = true, find_command = { "rg", "--files", "--hidden", "--follow", "--ignore-file", "~/.vimignore" } })<CR>', { noremap = true, silent = true })
-- map('n', '<leader>gt', '<cmd>lua require("telescope.builtin").live_grep()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tg', '<cmd>lua require("telescope.builtin").git_files()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>b', '<cmd>lua require("telescope.builtin").buffers()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>th', '<cmd>lua require("telescope.builtin").help_tags()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>T', '<cmd>lua require("telescope.builtin").tags()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>ts', '<cmd>lua require("telescope.builtin").spell_suggest()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tt', '<cmd>lua require("telescope.builtin").current_buffer_tags()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tf', '<cmd>lua require("telescope.builtin").current_buffer_fuzzy_find()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tc', '<cmd>lua require("telescope.builtin").commands()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>t:', '<cmd>lua require("telescope.builtin").command_history()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>t/', '<cmd>lua require("telescope.builtin").search_history()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>to', '<cmd>lua require("telescope.builtin").oldfiles()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tq', '<cmd>lua require("telescope.builtin").quickfix()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tl', '<cmd>lua require("telescope.builtin").loclist()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>th', '<cmd>lua require("telescope.builtin").highlights()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tr', '<cmd>lua require("telescope.builtin").registers()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>ti', '<cmd>lua require("telescope.builtin").treesitter()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tsb', '<cmd>lua require("telescope").extensions.repo.list{fd_opts=[[--ignore-file=~/.config/nvim/lua/plugins/telescope_fdignore]]}<CR>', { noremap = true, silent = true })
-- map('n', '<leader>y', '<cmd>lua require("telescope").extensions.neoclip.default()<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tch', '<cmd>:Cheatsheet<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tsn', '<cmd>lua require("telescope").extensions.luasnip.luasnip{}<CR>', { noremap = true, silent = true })
-- map('n', '<leader>fb', '<cmd>:Telescope file_browser<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tcd', ':Telescope coc diagnostics<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tcr', ':Telescope coc references<CR>', { noremap = true, silent = true })
-- map('n', '<leader>tu', ':Telescope ultisnips<CR>', { noremap = true, silent = true })
