-- nvim-treesitter (main branch) — https://github.com/nvim-treesitter/nvim-treesitter
--
-- The `main` branch dropped the old module system. There is no
-- configs.setup{highlight=..., indent=...} anymore:
--   * parsers are installed with require('nvim-treesitter').install{}
--   * highlighting is enabled per-buffer via vim.treesitter.start()
--   * indentation is enabled by setting 'indentexpr' (still experimental)
-- Both are wired up below through a single FileType autocmd.
--
-- Dropped from the old config (no longer supported on main):
--   * additional_vim_regex_highlighting — treesitter-only highlighting now
--   * matchup — was inert anyway (no andymass/vim-matchup plugin installed)
-- textobjects moved to its own plugin spec (see plugins/init.lua).

local ok, nvim_treesitter = pcall(require, "nvim-treesitter")
if not ok then
  vim.notify("require('nvim-treesitter') failed")
  return
end

-- On the first launch after switching to the `main` branch, lazy.nvim has not
-- yet checked it out (branch changes only apply on :Lazy sync/update), so the
-- old master module is still loaded and lacks .install. Bail out gracefully
-- with a hint instead of erroring.
if type(nvim_treesitter.install) ~= "function" then
  vim.notify(
    "nvim-treesitter still on the old branch — run :Lazy sync, then restart Neovim",
    vim.log.levels.WARN
  )
  return
end

local ensure_installed = {
  'bash',
  'c',
  'comment',
  'cpp',
  'css',
  'dockerfile',
  'fish',
  'gitignore',
  'go',
  'gomod',
  'gosum',
  'gotmpl',
  'gowork',
  'graphql',
  'hcl',
  'hocon',
  'html',
  'http',
  'java',
  'javascript',
  'jsdoc',
  'json',
  'kotlin',
  'latex',
  'lua',
  'make',
  'markdown',
  'markdown_inline',
  'regex',
  'rego',
  'ruby',
  'rust',
  'scala',
  'scss',
  'sql',
  'swift',
  'toml',
  'tsx',
  'typescript',
  'vim',
  'vimdoc',
  'yaml',
}

-- Install any missing parsers (async). `:TSUpdate` keeps them current; the
-- plugin's `build = ':TSUpdate'` step handles updates on install/upgrade.
nvim_treesitter.install(ensure_installed)

-- Enable treesitter highlighting + indentation for any buffer whose filetype
-- has an installed parser. vim.treesitter.start() errors when no parser is
-- available, so we guard it with pcall. yaml indentation stays disabled to
-- match the previous config.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
  callback = function(args)
    local started = pcall(vim.treesitter.start, args.buf)
    if started and args.match ~= "yaml" then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
