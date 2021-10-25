-- # ALIASES
local g = vim.g
local o = vim.opt
local exec = vim.api.nvim_exec

-- More natural split opening.
o.splitbelow = true
o.splitright = true

o.showcmd = true -- Show leader key

-- Tabs behaviour
o.expandtab = true -- On pressing tab, insert 2 spaces
o.tabstop = 2 -- show existing tab with 2 spaces width
o.softtabstop = 2
o.shiftwidth = 2 -- when indenting with '>', use 2 spaces width

-- Toggle Hybrid Numbers in insert and normal mode
o.relativenumber = true
o.number = true -- Show line numbers

-- #FINDING FILES
-- Use the `:find` command to fuzzy search files in the working directory
-- The `:b` command can also be used to do the same for open buffers

-- Search all subfolders
o.path = o.path + '**'

o.termguicolors = true -- enable 24-bit TUI colours

-- Display matching files on tab complete
o.wildmenu = true

-- Ignore node_modules and images from search results
o.wildignore = o.wildignore + '**/node_modules/**,**/dist/**,**_site/**,*.swp,*.png,*.jpg,*.gif,*.webp,*webm,*.ogg,*.dng,*.jpeg,*.map,*.woff*'

-- Show Invisibles
o.list = true
o.listchars = 'tab:→→,eol:¬,space:.'

-- Treat all numbers as decimal regardless of whether they are padded with zeros
o.nrformats = ''

-- Change case sensitivity behaviour
o.ignorecase = true -- needed for smartcase to work
o.smartcase = true -- make searches case insensitive except if uppercase charater is present

o.updatetime = 100

o.shell = '/usr/local/bin/fish'
g['$SHELL'] = '/usr/local/bin/fish'

-- Disable python2 provider
g.loaded_python_provider = 0
g.python_host_prog = ''

-- Disable ruby provider
g.loaded_ruby_provider = 0
g.ruby_host_prog = ''

-- Disable perl provider
g.loaded_perl_provider = 0
g.perl_host_prog = ''

-- Templates
-- Prefill new files created by vim with contents from the following templates
exec([[
augroup templates
  autocmd BufNewFile *.html 0r ~/.config/nvim/templates/skeleton.html
  autocmd BufNewFile *.scss 0r ~/.config/nvim/templates/skeleton.scss
  autocmd BufNewFile *.css 0r ~/.config/nvim/templates/skeleton.scss
  autocmd BufNewFile LICENCE 0r ~/.config/nvim/templates/skeleton.LICENCE
  autocmd BufNewFile LICENSE 0r ~/.config/nvim/templates/skeleton.LICENCE
  autocmd BufNewFile .gitignore 0r ~/.config/nvim/templates/skeleton.gitignore
  autocmd BufNewFile .stylelintrc.json 0r ~/.config/nvim/templates/skeleton.stylelintrc
  autocmd BufNewFile .eslintrc.json 0r ~/.config/nvim/templates/skeleton.eslintrc
  autocmd BufNewFile .prettierrc.json 0r ~/.config/nvim/templates/skeleton.prettierrc
augroup END
]], false)

-- Auto update dotfiles
-- exec([[ autocmd BufWritePost ~/.local/share/chezmoi/* silent! !chezmoi apply ]], false)

-- Strip trailing whitespace from all files
exec([[
autocmd BufWritePre * %s/\s\+$//e
autocmd BufWritePre * %s/\s\+$//e
autocmd BufWritePre * %s/\s\+$//e
]], false)

-- Toggle relative number mode
exec([[
:augroup numbertoggle
:  autocmd!
:  autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
:  autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
:augroup END
]], false)

-- set colorscheme
g.sonokai_style = 'shusia'
g.sonokai_enable_italic = 1
vim.cmd[[colorscheme sonokai]]

-- REFERENCES
-- https://github.com/ayoisaiah/dotfiles/blob/master/private_dot_config/nvim/lua/settings.lua
-- https://github.com/airblade/vim-gitgutter#when-are-the-signs-updated