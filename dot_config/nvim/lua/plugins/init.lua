local execute = vim.api.nvim_command
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
  use { 'plasticboy/vim-markdown', config = [[require('plugins.vim-markdown')]] }

  -- Telescope
  -- use { 'nvim-telescope/telescope.nvim', config = [[require('plugins.telescope')]] }
  -- use { 'fhill2/telescope-ultisnips.nvim' }
  -- use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }

  -- Git
  use { 'tpope/vim-fugitive', event = 'VimEnter', config = [[require('plugins.vim-fugitive')]] } -- Git wrapper for vim
  use { 'lewis6991/gitsigns.nvim', config = [[require('plugins.gitsigns')]] } -- Git signs
  use { 'rhysd/git-messenger.vim', event = 'VimEnter' } -- Show Git info in a popup

  -- Golang
  -- use { 'ray-x/go.nvim',
    -- config = function()
      -- require('go').setup()
      -- 1. format on save
      -- 2. import on save
      -- Run gofmt + goimport on save
  --     vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').goimport() ]], false)
  --   end,
  -- }
  -- use { 'mfussenegger/nvim-dap' }
  -- use { 'rcarriga/nvim-dap-ui' }
  -- use { 'theHamsta/nvim-dap-virtual-text', config = [[require('nvim-dap-virtual-text').setup()]] }
  -- use { 'nvim-telescope/telescope-dap.nvim' }
  -- use {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}

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
    requires = { 'kyazdani42/nvim-web-devicons', opt = true },
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

  -- cmp snippets
  use { 'L3MON4D3/LuaSnip' } --snippet engine
  use { 'rafamadriz/friendly-snippets' } -- a bunch of snippets to use

  -- use { 'neovim/nvim-lspconfig', config = [[require('lspconfig').gopls.setup{}]] }
  -- use { 'SirVer/ultisnips', config = [[require('plugins.ultisnips')]] } -- Snippets engine
  -- Treesitter
  -- use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate', config = [[require('plugins.treesitter')]] }
  -- use { 'nvim-treesitter/nvim-treesitter-textobjects' }

  -- Utilities
  use { 'windwp/nvim-autopairs', config = [[require('plugins.nvim-autopairs')]] } -- Insert or delete brackets, parens, quotes in pair.
  use { 'numtostr/comment.nvim', config = [[require('plugins.comment')]] } -- Comment stuff out easily
  use { 'miyakogi/conoline.vim', config = [[require('plugins.conoline')]] } -- Highlight the line of the cusor in the current window
  use { 'airblade/vim-rooter', config = [[require('plugins.vim-rooter')]] } -- Change vim working directory to project directory
  use { 'fladson/vim-kitty' } -- highlighting support for kitty config
  use { 'alker0/chezmoi.vim' } -- highlighting support for chezmoi templates


  if PACKER_BOOTSTRAP then
    require('packer').sync()
  end
end)
