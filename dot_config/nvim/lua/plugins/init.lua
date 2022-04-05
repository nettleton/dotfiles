local execute = vim.api.nvim_command
local fn = vim.fn

local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

-- Auto compile when there are changes in plugins.lua
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

require('packer').startup(function(use)
  -- Packer can manage itself
  use { 'wbthomason/packer.nvim' }
  use { 'lewis6991/impatient.nvim', config = [[require('impatient')]] } -- Speed up startup time


  -- Markdown
  use { 'plasticboy/vim-markdown', config = [[require('plugins.vim-markdown')]] }
--   use { 'vim-pandoc/vim-pandoc-syntax' }

  -- Telescope
  use { 'nvim-lua/plenary.nvim' }
  use { 'nvim-telescope/telescope.nvim', config = [[require('plugins.telescope')]] }
  use { 'fannheyward/telescope-coc.nvim' }
  use { 'fhill2/telescope-ultisnips.nvim' }
  use { 'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }

  -- Git
  use { 'tpope/vim-fugitive', event = 'VimEnter', config = [[require('plugins.vim-fugitive')]] } -- Git wrapper for vim
  use { 'lewis6991/gitsigns.nvim', config = [[require('plugins.gitsigns')]] } -- Git signs
  use { 'rhysd/git-messenger.vim', event = 'VimEnter' } -- Show Git info in a popup

  -- Golang
  use { 'ray-x/go.nvim',
    config = function()
      require('go').setup()
      -- 1. format on save
      -- 2. import on save
      -- Run gofmt + goimport on save
      vim.api.nvim_exec([[ autocmd BufWritePre *.go :silent! lua require('go.format').goimport() ]], false)
    end,
  }
  use { 'mfussenegger/nvim-dap' }
  use { 'rcarriga/nvim-dap-ui' }
  use { 'theHamsta/nvim-dap-virtual-text', config = [[require('nvim-dap-virtual-text').setup()]] }
  use { 'nvim-telescope/telescope-dap.nvim' }
  use {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}

  -- Appearance and themes
  use { 'sainnhe/sonokai', 
    config = function()
      vim.g.sonokai_style = 'shusia'
      vim.g.sonokai_enable_italic = 1
      vim.cmd[[colorscheme sonokai]]
    end,
  }
  use {
    'nvim-lualine/lualine.nvim',
    requires = { 'kyazdani42/nvim-web-devicons', opt = true },
    config = [[require('plugins.lualine')]]
  } -- Statusline
  use { 'akinsho/nvim-bufferline.lua', config = [[require('plugins.nvim-bufferline')]] } -- Better nvim buffers
--   use { 'lukas-reineke/indent-blankline.nvim' } -- Indenting
--   use { 'norcalli/nvim-base16.lua' } -- Theme colours

  -- Autocompletion, formatting, linting & intellisense
  use {
    'neoclide/coc.nvim', -- Intellisense, LSP and other language smarts
    run = 'yarn install --frozen-lockfile',
    config = [[require('plugins.coc-nvim')]]
  }
  use { 'neovim/nvim-lspconfig', config = [[require('lspconfig').gopls.setup{}]] }
  use { 'neoclide/coc-prettier', run = 'yarn install --frozen-lockfile' }
  use { 'SirVer/ultisnips', config = [[require('plugins.ultisnips')]] } -- Snippets engine
  use { 'alker0/chezmoi.vim' } -- support for chezmoi templates

  -- Treesitter
  use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate', config = [[require('plugins.treesitter')]] }
  use { 'nvim-treesitter/nvim-treesitter-textobjects' }

  -- Utilities
--   use { 'romainl/vim-qf' } -- Quick fix settings, commands and mappings
--   use { 'moll/vim-bbye' } -- Delete buffers without closing windows
  use { 'windwp/nvim-autopairs', config = [[require('plugins.nvim-autopairs')]] } -- Insert or delete brackets, parens, quotes in pair.
--   use { 'mattn/emmet-vim', event = 'VimEnter', ft = {'html', 'markdown', 'css', 'scss'} } -- Shortcuts for writing HTML and CSS
--   use { 'norcalli/nvim-colorizer.lua', ft = { 'html', 'css', 'scss', 'javascript' } } -- Colour highlighting
  use { 'ervandew/supertab', config = [[require('plugins.supertab')]] } -- Use <Tab> for autocompletion in insert mode
--   use { 'tpope/vim-surround' } -- Mappings for surroundings like brackets, quotes, e.t.c.
  use { 'numtostr/comment.nvim', config = [[require('plugins.comment')]] } -- Comment stuff out easily
--   use { 'tpope/vim-repeat' } -- Enhance the dot command
--   use { 'tpope/vim-unimpaired' } -- Custom mappings for some ex commands
--   use { 'luochen1990/rainbow' } -- Use different colours for parenthesis levels
--   use { 'ludovicchabant/vim-gutentags' } -- Manage tag files automatically
--   use { 'wakatime/vim-wakatime', event = 'VimEnter' } -- Auto generated metrics and time tracking
  use { 'miyakogi/conoline.vim', config = [[require('plugins.conoline')]] } -- Highlight the line of the cusor in the current window
  use { 'airblade/vim-rooter', config = [[require('plugins.vim-rooter')]] } -- Change vim working directory to project directory
--   use { 'andymass/vim-matchup', event = 'VimEnter' } -- Highlight, navigate, and operate on sets of matching text
  use { 'fladson/vim-kitty' }

  if packer_bootstrap then
    require('packer').sync()
  end
end)

-- Config

-- require('plugins.gitsigns')
-- require('plugins.telescope')
-- require('plugins.treesitter')
-- require('plugins.vim-fugitive')
-- require('plugins.vim-markdown')
-- require('plugins.lualine')
-- require('plugins.nvim-bufferline')
-- require('plugins.coc-nvim')
-- require('plugins.ultisnips')
-- require('plugins.nvim-autopairs')
-- require('plugins.conoline')
-- require('plugins.comment')
-- require('plugins.go')
-- require('plugins.vim-rooter')
-- require('plugins.supertab')

-- not used yet
-- require('plugins.emmet-vim')
-- require('plugins.indent-blankline')
-- require('plugins.rainbow')
-- require('plugins.vim-bbye')
-- require('plugins.vim-gutentags')
-- require('plugins.vim-pandoc')
-- require('plugins.vim-qf')

