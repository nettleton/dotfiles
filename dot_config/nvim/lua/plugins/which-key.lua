local which_key_ok, which_key = pcall(require, "which-key")
if not which_key_ok then
  vim.notify("require('which-key') failed")
  return
end

which_key.setup {
  -- https://github.com/folke/which-key.nvim/
}

which_key.register({
  d = { '"*d', "Cut to OS clipboard" },
  p = { '"*p', "Paste OS clipboard" },
  P = { '"*P', "Another Paste ?"},
  y = { '"*y', "Copy/Yank to OS clipboard"}
}, { mode = 'v', prefix = "<leader>", noremap = true, silent = true })

which_key.register({
  b = {
    name = "Buffer",
    c = { ':BufferLinePickClose<CR>', "Close" },
    d = { ':bd<CR>', "Delete Current" },
    j = { ':bnext<CR>', "Next Buffer" },
    k = { ':bprevious<CR>', "Previous Buffer" },
    n = { ':BufferLineCycleNext<CR>', "Next" },
    p = { ':BufferLineCyclePrev<CR>', "Previous" },
    s = { ':BufferLinePick<CR>', "Select" },
    ["1"] = { ':BufferLineGoToBuffer 1<CR>', "Switch to Buffer 1" },
    ["2"] = { ':BufferLineGoToBuffer 2<CR>', "Switch to Buffer 2" },
    ["3"] = { ':BufferLineGoToBuffer 3<CR>', "Switch to Buffer 3" },
    ["4"] = { ':BufferLineGoToBuffer 4<CR>', "Switch to Buffer 4" },
    ["5"] = { ':BufferLineGoToBuffer 5<CR>', "Switch to Buffer 5" },
  }
}, { prefix = "<leader>", noremap = true, silent = true })

which_key.register({
  f = {
    name = "Find",
    a = { '<cmd>:Telescope telescope-tabs list_tab<CR>', "Tabs" },
    b = { '<cmd>lua require("telescope.builtin").buffers()<CR>', "Buffer" },
    ["/"] = { '<cmd>lua require("telescope.builtin").current_buffer_fuzzy_find()<CR>', "Buffer Grep" },
    c = { '<cmd>:Cheatsheet<CR>', "Cheatsheet" },
    d = { '<cmd>:Telescope lsp_document_symbols<CR>', "Document Symbols" },
    f = { '<cmd>lua require("telescope.builtin").find_files({ hidden = true, find_command = { "rg", "--files", "--hidden", "--follow", "--ignore-file", "~/.vimignore" } })<CR>',
      "File" },
    F = "File Kinds",
    g = { '<cmd>lua require("telescope.builtin").live_grep()<CR>', "Grep" },
    h = "History",
    l = { '<cmd>lua require("telescope").extensions.luasnip.luasnip{}<CR>', "Snippets" },
    p = { '<cmd>:Telescope lazy<CR>', "Lazy" },
    r = { '<cmd>lua require("telescope").extensions.repo.list{fd_opts=[[--ignore-file=~/.config/nvim/lua/plugins/telescope_fdignore]]}<CR>',
      "Repos" },
    s = { '<cmd>lua require("telescope.builtin").spell_suggest()<CR>', "Spelling" },
    t = { '<cmd>lua require("telescope.builtin").treesitter()<CR>', "Treesitter" },
    y = { '<cmd>lua require("telescope").extensions.neoclip.default()<CR>', "Yank" },
  }
}, { prefix = "<leader>", noremap = true, silent = true })

which_key.register({
  F = {
    name = "File Kinds",
    b = { '<cmd>:Telescope file_browser<CR>', "File Browser" },
    g = { '<cmd>lua require("telescope.builtin").git_files()<CR>', "Git Files" },
    o = { '<cmd>lua require("telescope.builtin").oldfiles()<CR>', "Old Files" },
  }
}, { prefix = "<leader>f", noremap = true, silent = true})

which_key.register({
  h = {
    name = "History",
    c = { '<cmd>lua require("telescope.builtin").command_history()<CR>', "Commands" },
    s = { '<cmd>lua require("telescope.builtin").search_history()<CR>', "Searches" },
  }
}, { prefix = "<leader>f", noremap = true, silent = true })

which_key.register({
  g = {
    name = "Git",
    a = { ':Git commit --amend<CR>', "Amend" },
    b = { ':GBrowse<CR>', "Browse on GitHub"},
    c = { ':Git commit --verbose<CR>', "Commit" },
    m = { ':GitMessenger<CR>', 'Show Message'},
    w = { ':Gwrite<CR>', "Write" },
  }
}, { prefix = "<leader>", noremap = true, silent = true })


which_key.register({
  l = {
    name = "Language / LSP",
    d = { '<cmd>:Telescope lsp_document_symbols<CR>', "Document Symbols" },
    f = { '<cmd>lua vim.lsp.buf.formatting()<CR>', "Format" },
    g = "GoTo",
    h = { '<cmd>lua vim.lsp.buf.hover()<CR>', "Hover" },
    j = { '<cmd>lua vim.diagnostic.goto_next({ border = "rounded" })<CR>', "GoTo Next" },
    k = { '<cmd>lua vim.diagnostic.goto_prev({ border = "rounded" })<CR>', "GoTo Previous" },
    r = { '<cmd>lua vim.lsp.buf.references()<CR>', "References" },
    o = { '<cmd>lua vim.diagnostic.open_float(0, { scope = "line", border = "single" })<CR>', "Open" },
    s = { '<cmd>lua vim.lsp.buf.signature_help()<CR>', "Signature Help" },
  }
}, { prefix = "<leader>", noremap = true, silent = true })

which_key.register({
  g = {
    name = "GoTo",
    d = { '<cmd>lua vim.lsp.buf.declaration()<CR>', "GoTo Declaration" },
    f = { '<cmd>lua vim.lsp.buf.definition()<CR>', "GoTo Definition" },
    i = { '<cmd>lua vim.lsp.buf.implementation()<CR>', "GoTo Implementation" },
  }
}, { prefix = "<leader>l", noremap = true, silent = true } )

which_key.register({
  w = {
    name = "Window",
    c = { '<C-w>c', "Close" },
    h = { '<C-w>h', "Left" },
    j = { '<C-w>j', "Below" },
    k = { '<C-w>k', "Above" },
    l = { '<C-w>l', "Right" },
    n = "New",
    q = { '<C-w>q', "Quit" },
    s = "Size",
  }
}, { prefix = "<leader>", noremap = true, silent = true })

which_key.register({
  n = {
    name = "New",
    h = { ':split', "New Horizontal Split" },
    v = { ':vsplit', "New Vertical Split" },
  }
}, { prefix = "<leader>w", noremap = true, silent = true })

which_key.register({
  s = {
    name = "Size",
    h = { ':vertical resize -2<CR>', "Resize Narrower" },
    j = { ':resize +2<CR>', "Resize Taller" },
    k = { ':resize -2<CR>', "Resize Shorter" },
    l = { ':vertical resize +2<CR>', "Resize Wider" },
  }
}, { prefix = "<leader>w", noremap = true, silent = true })

which_key.register({
  -- c = "Comment",
  t = { ':TroubleToggle<CR>', "Trouble" }
}, { prefix = "<leader>", noremap = true, silent = true} )

which_key.register({
  v = {
    name = "View",
    s = { '<cmd>AerialToggle!<CR>', "Toggle Aerial" }
  }
}, { prefix = "<leader>", noremap = true, silent = true})

-- which_key.register({
  -- c = "Comment",
-- }, { mode = 'v', prefix = "<leader>", noremap = true, silent = true} )
