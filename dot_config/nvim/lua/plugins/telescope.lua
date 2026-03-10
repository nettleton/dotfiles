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
      list = {
        fd_opts = {
          "--no-ignore-vcs",
        },
        search_dirs = {
          "~/sandbox",
        },
      },
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
telescope.load_extension('telescope-tabs')
