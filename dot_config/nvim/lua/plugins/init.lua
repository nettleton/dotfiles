local fn = vim.fn

local lazypath = fn.stdpath('data')..'/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require("lazy").setup({
  spec = {
    { 'nvim-lua/popup.nvim' },    -- An implementation of the Popup API from vim in Neovim
    { 'nvim-lua/plenary.nvim' },  -- Useful lua functions used by lots of plugins

  -- Markdown
    { 'preservim/vim-markdown',
        dependencies = {
          { 'godlygeek/tabular' }
        },
        config = function()
          require('plugins.vim-markdown')
        end,
    },
    { 'gaoDean/autolist.nvim',
      ft = {
        "markdown",
        "text",
        "tex",
        "plaintex",
        "norg",
      },
      config = function()
        require("autolist").setup()
        vim.keymap.set("i", "<tab>", "<cmd>AutolistTab<cr>")
        vim.keymap.set("i", "<s-tab>", "<cmd>AutolistShiftTab<cr>")
        -- vim.keymap.set("i", "<c-t>", "<c-t><cmd>AutolistRecalculate<cr>") -- an example of using <c-t> to indent
        vim.keymap.set("i", "<CR>", "<CR><cmd>AutolistNewBullet<cr>")
        vim.keymap.set("n", "o", "o<cmd>AutolistNewBullet<cr>")
        vim.keymap.set("n", "O", "O<cmd>AutolistNewBulletBefore<cr>")
        vim.keymap.set("n", "<CR>", "<cmd>AutolistToggleCheckbox<cr><CR>")
        vim.keymap.set("n", "<C-r>", "<cmd>AutolistRecalculate<cr>")

        -- cycle list types with dot-repeat
        vim.keymap.set("n", "<leader>cn", require("autolist").cycle_next_dr, { expr = true })
        vim.keymap.set("n", "<leader>cp", require("autolist").cycle_prev_dr, { expr = true })

        -- if you don't want dot-repeat
        -- vim.keymap.set("n", "<leader>cn", "<cmd>AutolistCycleNext<cr>")
        -- vim.keymap.set("n", "<leader>cp", "<cmd>AutolistCycleNext<cr>")

        -- functions to recalculate list on edit
        vim.keymap.set("n", ">>", ">><cmd>AutolistRecalculate<cr>")
        vim.keymap.set("n", "<<", "<<<cmd>AutolistRecalculate<cr>")
        vim.keymap.set("n", "dd", "dd<cmd>AutolistRecalculate<cr>")
        vim.keymap.set("v", "d", "d<cmd>AutolistRecalculate<cr>")
      end,
    },

  -- Telescope
    { 'nvim-telescope/telescope.nvim',
      dependencies = {
        {"nvim-lua/plenary.nvim"},
        {"tsakirist/telescope-lazy.nvim"},
      },
      config = function()
        require('plugins.telescope')
      end,
    },
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    { 'cljoly/telescope-repo.nvim',
        dependencies = {
          { 'nvim-lua/plenary.nvim' }
        }
    },
    { 'AckslD/nvim-neoclip.lua',
        dependencies = {
          {'kkharji/sqlite.lua'},
          {'nvim-telescope/telescope.nvim'},
        },
        config = function()
          require('neoclip').setup()
        end,
    },
    { 'sudormrfbin/cheatsheet.nvim',
        dependencies = {
          {'nvim-telescope/telescope.nvim'},
          {'nvim-lua/popup.nvim'},
          {'nvim-lua/plenary.nvim'},
        },

        config = function()
          require('cheatsheet').setup()
        end,
    },
    { "benfowler/telescope-luasnip.nvim" },
    { "nvim-telescope/telescope-file-browser.nvim",
      dependencies = {
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons"
      }
    },
    { 'LukasPietzschmann/telescope-tabs',
      dependencies = { 'nvim-telescope/telescope.nvim' },
      config = function()
        require('telescope-tabs').setup{
          -- Your custom config :^)
        }
      end
    },

  -- Git
    { 'tpope/vim-fugitive', event = 'VimEnter' }, -- Git wrapper for vim
    { 'tpope/vim-rhubarb',
      dependencies = { 'tpope/vim-fugitive' },
      event = 'VimEnter'
    }, -- Open files in GitHub UI
    { 'lewis6991/gitsigns.nvim',
      config = function()
        require('plugins.gitsigns')
      end,
    }, -- Git signs
    { 'rhysd/git-messenger.vim', event = 'VimEnter' }, -- Show Git info in a popup

  -- Golang
    { 'ray-x/go.nvim',
      dependencies = {
        "ray-x/guihua.lua",
        "neovim/nvim-lspconfig",
        "nvim-treesitter/nvim-treesitter"
      },
      config = function()
        require('go').setup({
          gofmt = 'golines',
          goimports = 'golines',
          max_line_len = 999,
        })
        -- Run gofmt + goimport on save
        local format_sync_grp = vim.api.nvim_create_augroup("GoFormat", {})
        vim.api.nvim_create_autocmd("BufWritePre", {
          pattern = "*.go",
          callback = function()
           require('go.format').goimport()
          end,
          group = format_sync_grp,
        })
      end,
      event = {"CmdlineEnter"},
      ft = {"go", "gomod"},
      build = ':lua require("go.install").update_all_sync()'
    },
    { 'ray-x/guihua.lua', build = 'cd lua/fzy && make'},
    { 'leoluz/nvim-dap-go',
      config = function()
        require('dap-go').setup()
      end,
    },

  -- DAP / debugging
    { 'mfussenegger/nvim-dap' },
    { 'rcarriga/nvim-dap-ui',
      dependencies = {
        'mfussenegger/nvim-dap',
        'nvim-neotest/nvim-nio'
      },
      config = function()
        require('dapui').setup()
      end,
    },
    { 'theHamsta/nvim-dap-virtual-text',
      config = function()
        require('nvim-dap-virtual-text').setup()
      end,
    },
    { 'nvim-telescope/telescope-dap.nvim' },

  -- Appearance and themes
    { 'sainnhe/sonokai',
      config = function()
        vim.g.sonokai_style = 'shusia'
        vim.g.sonokai_enable_italic = 1
        vim.cmd[[colorscheme sonokai]]
      end,
    },

  -- Statusline
    { 'nvim-lualine/lualine.nvim',
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      config = function()
        require('plugins.lualine')
      end,
    },
    { 'akinsho/nvim-bufferline.lua',
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      config = function()
        require('plugins.nvim-bufferline')
      end,
    }, -- Better nvim buffers

  -- Autocompletion, formatting, linting & intellisense
  -- cmp plugins
    { 'hrsh7th/nvim-cmp',
      config = function()
        require('plugins.cmp')
      end,
    }, -- The completion plugin
    { 'hrsh7th/cmp-buffer' }, -- buffer completions
    { 'hrsh7th/cmp-path' }, -- path completions
    { 'hrsh7th/cmp-cmdline' }, -- cmdline completions
    { 'saadparwaiz1/cmp_luasnip' }, -- snippet completions
    { 'mtoohey31/cmp-fish', ft = 'fish' }, -- fish completions
    { 'hrsh7th/cmp-nvim-lsp' }, -- lsp completions
    { 'hrsh7th/cmp-nvim-lua' }, -- neovim lua API completions
    { 'hrsh7th/cmp-nvim-lsp-signature-help' }, -- LSP signature suggestions
    { 'ray-x/cmp-treesitter' }, -- treesitter nodes
    { 'rcarriga/cmp-dap' }, -- nvim-dap

  -- cmp snippets
    { 'L3MON4D3/LuaSnip',
      version = "v2.*",
      build = "make install_jsregexp",
      config = function()
        require('luasnip.loaders.from_vscode').lazy_load({paths="~/.config/nvim/snips"})
      end,
    }, --snippet engine
    { 'rafamadriz/friendly-snippets' }, -- a bunch of snippets to use

  -- LSP
    { 'williamboman/mason.nvim' },
    { 'williamboman/mason-lspconfig.nvim' },
    { 'WhoIsSethDaniel/mason-tool-installer.nvim',
      dependencies = { 'williamboman/mason.nvim' } },
    { 'neovim/nvim-lspconfig' },
    { 'b0o/schemastore.nvim' },
    { 'nvimtools/none-ls.nvim',
      dependencies = {
        'nvim-lua/plenary.nvim',
        'nvimtools/none-ls-extras.nvim',
        'gbprod/none-ls-shellcheck.nvim',
        'gbprod/none-ls-luacheck.nvim',
      }
    },
    { "folke/trouble.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      config = function()
        require("trouble").setup {
          -- your configuration comes here
          -- https://github.com/folke/trouble.nvim/
        }
      end
    },

  -- Treesitter
    { 'nvim-treesitter/nvim-treesitter',
      build = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
      config = function()
        require('plugins.treesitter')
      end,
      dependencies = {
        { 'nvim-treesitter/nvim-treesitter-textobjects' },
      }
    },
    { 'HiPhish/rainbow-delimiters.nvim' },
    { 'stevearc/aerial.nvim',
      opts = {},
      -- Optional dependencies
      dependencies = {
         "nvim-treesitter/nvim-treesitter",
         "nvim-tree/nvim-web-devicons"
      },
    },

  -- Utilities
    { 'windwp/nvim-autopairs',
      config = function()
        require('plugins.nvim-autopairs')
      end
    }, -- Insert or delete brackets, parens, quotes in pair.
    { 'numtostr/comment.nvim',
      config = function()
        require('plugins.comment')
      end,
      lazy = false,
    }, -- Comment stuff out easily
    { 'miyakogi/conoline.vim',
          config = function()
            require('plugins.conoline')
          end,
        }, -- Highlight the line of the cursor in the current window
    { 'airblade/vim-rooter',
          config = function()
            require('plugins.vim-rooter')
          end,
        }, -- Change vim working directory to project directory
    { 'fladson/vim-kitty' }, -- highlighting support for kitty config
    { 'alker0/chezmoi.vim' }, -- highlighting support for chezmoi templates

    { 'folke/which-key.nvim',
      config = function()
        require('plugins.which-key')
      end,
    }, -- key bindings
    { 'AckslD/messages.nvim',
      config = function()
        require("messages").setup()
      end,
    },

  -- strip trailing whitespace from edited lines
    { 'lewis6991/spaceless.nvim',
      config = function()
        require('spaceless').setup()
      end,
    },

  -- ZK
    { 'zk-org/zk-nvim',
      config = function()
        require('zk').setup()
      end,
    },
  },
  defaults = {
     -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = {},
  checker = { enabled = true },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        -- "matchit",
        -- "matchparen",
        -- "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
