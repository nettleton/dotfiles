local fn = vim.fn

local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system {
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  }
  print "Installing packer close and reopen Neovim..."
  vim.cmd [[packadd packer.nvim]]
end

-- Auto compile when there are changes in plugins.lua
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost */plugins/init.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  vim.notify("require('packer') failed")
  return
end

-- Have packer use a popup window
packer.init {
  display = {
    open_fn = function()
      return require("packer.util").float { border = "rounded" }
    end,
  },
}

-- Install your plugins here
return packer.startup(function(use)
  -- Packer can manage itself
  use { 'wbthomason/packer.nvim' } -- Have packer manage itself
  use { 'lewis6991/impatient.nvim' } -- Speed up startup time

  use { 'nvim-lua/popup.nvim' }    -- An implementation of the Popup API from vim in Neovim
  use { 'nvim-lua/plenary.nvim' }  -- Useful lua functions used by lots of plugins

  -- Markdown
  use { 'preservim/vim-markdown',
        requires = {
          { 'godlygeek/tabular' }
        },
        config = [[require('plugins.vim-markdown')]] }
  use { 'gaoDean/autolist.nvim',
        config = function()
          local autolist = require("autolist")
          autolist.setup()
          autolist.create_mapping_hook("i", "<CR>", autolist.new)
          autolist.create_mapping_hook("i", "<Tab>", autolist.indent)
          autolist.create_mapping_hook("i", "<S-Tab>", autolist.indent, "<C-D>")
          autolist.create_mapping_hook("n", "o", autolist.new)
          autolist.create_mapping_hook("n", "O", autolist.new_before)
          autolist.create_mapping_hook("n", ">>", autolist.indent)
          autolist.create_mapping_hook("n", "<<", autolist.indent)
          autolist.create_mapping_hook("n", "<C-r>", autolist.force_recalculate)
          autolist.create_mapping_hook("n", "<leader>x", autolist.invert_entry, "")
          vim.api.nvim_create_autocmd("TextChanged", {
            pattern = "*",
            callback = function()
              vim.cmd.normal({autolist.force_recalculate(nil, nil), bang = false})
            end
          })
        end,
      }

  -- Telescope
  use {
    'nvim-telescope/telescope.nvim',
    config = [[require('plugins.telescope')]],
  }
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
  use { 'cljoly/telescope-repo.nvim',
    requires = {
      { 'nvim-lua/plenary.nvim' }
    }
  }
  use {
    'AckslD/nvim-neoclip.lua',
    requires = {
      {'kkharji/sqlite.lua', module = 'sqlite'},
      {'nvim-telescope/telescope.nvim'},
    },
    config = function()
      require('neoclip').setup()
    end,
  }
  use {
    'sudormrfbin/cheatsheet.nvim',

    requires = {
      {'nvim-telescope/telescope.nvim'},
      {'nvim-lua/popup.nvim'},
      {'nvim-lua/plenary.nvim'},
    },

    config = [[require('cheatsheet').setup()]]
  }
  use {
    "benfowler/telescope-luasnip.nvim",
    module = "telescope._extensions.luasnip",  -- if you wish to lazy-load
  }
  use { 'nvim-telescope/telescope-file-browser.nvim' }
  use { 'nvim-telescope/telescope-packer.nvim' }
  use {
    'LukasPietzschmann/telescope-tabs',
    requires = { 'nvim-telescope/telescope.nvim' },
    config = function()
      require('telescope-tabs').setup{
          -- Your custom config :^)
      }
    end
  }

  -- Git
  use { 'tpope/vim-fugitive', event = 'VimEnter' } -- Git wrapper for vim
  use {
    'tpope/vim-rhubarb',
    requires = { 'tpope/vim-fugitive' },
    event = 'VimEnter'
  } -- Open files in GitHub UI
  use { 'lewis6991/gitsigns.nvim', config = [[require('plugins.gitsigns')]] } -- Git signs
  use { 'rhysd/git-messenger.vim', event = 'VimEnter' } -- Show Git info in a popup

  -- Golang
  use { 'ray-x/go.nvim',
    config = function()
      require('go').setup({
        gofmt = 'gofmt',
        max_line_len = 999,
      })
      -- Run gofmt + goimport on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.go",
        callback = function()
         require('go.format').goimport()
        end,
        group = format_sync_grp,
      })

    end,
  }
  use {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}
  use { 'leoluz/nvim-dap-go', config = [[require('dap-go').setup()]] }

  -- DAP / debugging
  use { 'mfussenegger/nvim-dap' }
  use {
    'rcarriga/nvim-dap-ui',
    requires = { 'mfussenegger/nvim-dap' },
    config = [[require('dapui').setup()]]
  }
  use { 'theHamsta/nvim-dap-virtual-text', config = [[require('nvim-dap-virtual-text').setup()]] }
  use { 'nvim-telescope/telescope-dap.nvim' }

  -- Appearance and themes
  use { 'sainnhe/sonokai',
    config = function()
      vim.g.sonokai_style = 'shusia'
      vim.g.sonokai_enable_italic = 1
      vim.cmd[[colorscheme sonokai]]
    end,
  }

  -- Statusline
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'kyazdani42/nvim-web-devicons' },
    config = [[require('plugins.lualine')]]
  }
  use { 'akinsho/nvim-bufferline.lua', config = [[require('plugins.nvim-bufferline')]] } -- Better nvim buffers

  -- Autocompletion, formatting, linting & intellisense
  -- cmp plugins
  use { 'hrsh7th/nvim-cmp', config = [[require('plugins.cmp')]] } -- The completion plugin
  use { 'hrsh7th/cmp-buffer' } -- buffer completions
  use { 'hrsh7th/cmp-path' } -- path completions
  use { 'hrsh7th/cmp-cmdline' } -- cmdline completions
  use { 'saadparwaiz1/cmp_luasnip' } -- snippet completions
  use { 'mtoohey31/cmp-fish', ft = 'fish' } -- fish completions
  use { 'hrsh7th/cmp-nvim-lsp' } -- lsp completions
  use { 'hrsh7th/cmp-nvim-lua' } -- neovim lua API completions
  use { 'hrsh7th/cmp-nvim-lsp-signature-help' } -- LSP signature suggestions
  use { 'ray-x/cmp-treesitter' } -- treesitter nodes
  use { 'rcarriga/cmp-dap' } -- nvim-dap

  -- cmp snippets
  use { 'L3MON4D3/LuaSnip', config = [[require('luasnip.loaders.from_vscode').lazy_load({paths="~/.config/nvim/snips"})]] } --snippet engine
  use { 'rafamadriz/friendly-snippets' } -- a bunch of snippets to use

  -- LSP
  use { 'williamboman/mason.nvim' }
  use { 'williamboman/mason-lspconfig.nvim' }
  use { 'WhoIsSethDaniel/mason-tool-installer.nvim', requires = { 'williamboman/mason.nvim' } }
  use { 'neovim/nvim-lspconfig' }
  use { 'b0o/schemastore.nvim' }
  use { 'jose-elias-alvarez/null-ls.nvim' }
  use {
    "folke/trouble.nvim",
    requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require("trouble").setup {
        -- your configuration comes here
        -- https://github.com/folke/trouble.nvim/
      }
    end
  }

  -- Treesitter
  use {
    'nvim-treesitter/nvim-treesitter',
    run = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
    config = [[require('plugins.treesitter')]]
  }
  use { 'nvim-treesitter/nvim-treesitter-textobjects' }
  use { 'p00f/nvim-ts-rainbow' }
  use { 'simrat39/symbols-outline.nvim', config = [[require('symbols-outline').setup()]] }

  -- Utilities
  use { 'windwp/nvim-autopairs', config = [[require('plugins.nvim-autopairs')]] } -- Insert or delete brackets, parens, quotes in pair.
  use { 'numtostr/comment.nvim', config = [[require('plugins.comment')]] } -- Comment stuff out easily
  use { 'miyakogi/conoline.vim', config = [[require('plugins.conoline')]] } -- Highlight the line of the cusor in the current window
  use { 'airblade/vim-rooter', config = [[require('plugins.vim-rooter')]] } -- Change vim working directory to project directory
  use { 'fladson/vim-kitty' } -- highlighting support for kitty config
  use { 'alker0/chezmoi.vim' } -- highlighting support for chezmoi templates

  use { 'folke/which-key.nvim', config = [[require('plugins.which-key')]] } -- key bindings

  -- strip trailing whitespace from edited lines
  use {
    'lewis6991/spaceless.nvim', config = [[require('spaceless').setup()]]}

  -- ZK
  use { 'mickael-menu/zk-nvim', config = [[require('zk').setup()]] }

  if PACKER_BOOTSTRAP then
    require('packer').sync()
  end
end)
