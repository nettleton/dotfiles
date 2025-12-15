-- require('nvim-treesitter').install {
--   'bash',
--   'c',
--   'comment',
--   'cpp',
--   'css',
--   'dockerfile',
--   'fish',
--   'gitignore',
--   'go',
--   'gomod',
--   'gosum',
--   'gotmpl',
--   'gowork',
--   'graphql',
--   'hcl',
--   'hocon',
--   'html',
--   'http',
--   'java',
--   'javascript',
--   'jsdoc',
--   'json',
--   'kotlin',
--   'latex',
--   'lua',
--   'make',
--   'markdown',
--   'regex',
--   'rego',
--   'ruby',
--   'rust',
--   'scala',
--   'scss',
--   'sql',
--   'swift',
--   'toml',
--   'tsx',
--   'typescript',
--   'vim',
--   'yaml'
-- }
--

local treesitter_configs_ok, treesitter_configs = pcall(require, "nvim-treesitter.config")
if not treesitter_configs_ok then
  vim.notify("require('nvim-treesitter.config') failed")
  return
end
treesitter_configs.setup {
    ensure_installed = {
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
      'yaml'
    },
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = true,
    },
    indent = {
      enable = true,
      disable = {
        'yaml'
      },
    },
    matchup = {
      enable = true,
    },
    textobjects = {
      select = {
        enable = true,

        -- Automatically jump forward to textobj, similar to targets.vim
        lookahead = true,

        keymaps = {
          -- You can use the capture groups defined in textobjects.scm
          -- ["af"] = "@function.outer",
          -- ["if"] = "@function.inner",
          -- ["ac"] = "@class.outer",
          -- ["ic"] = "@class.inner",
        },
      },
    },
  }
