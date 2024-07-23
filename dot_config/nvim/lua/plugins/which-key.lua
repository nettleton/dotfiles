local which_key_ok, which_key = pcall(require, "which-key")
if not which_key_ok then
  vim.notify("require('which-key') failed")
  return
end

which_key.setup {
  -- https://github.com/folke/which-key.nvim/
}

which_key.add({
  {
    mode = { "v" },
    { "<leader>P", '"*P', desc = "Another Paste ?", remap = false },
    { "<leader>d", '"*d', desc = "Cut to OS clipboard", remap = false },
    { "<leader>p", '"*p', desc = "Paste OS clipboard", remap = false },
    { "<leader>y", '"*y', desc = "Copy/Yank to OS clipboard", remap = false },
  },
})

which_key.add({
  { "<leader>b", group = "Buffer", remap = false },
  { "<leader>b1", ":BufferLineGoToBuffer 1<CR>", desc = "Switch to Buffer 1", remap = false },
  { "<leader>b2", ":BufferLineGoToBuffer 2<CR>", desc = "Switch to Buffer 2", remap = false },
  { "<leader>b3", ":BufferLineGoToBuffer 3<CR>", desc = "Switch to Buffer 3", remap = false },
  { "<leader>b4", ":BufferLineGoToBuffer 4<CR>", desc = "Switch to Buffer 4", remap = false },
  { "<leader>b5", ":BufferLineGoToBuffer 5<CR>", desc = "Switch to Buffer 5", remap = false },
  { "<leader>bc", ":BufferLinePickClose<CR>", desc = "Close", remap = false },
  { "<leader>bd", ":bd<CR>", desc = "Delete Current", remap = false },
  { "<leader>bj", ":bnext<CR>", desc = "Next Buffer", remap = false },
  { "<leader>bk", ":bprevious<CR>", desc = "Previous Buffer", remap = false },
  { "<leader>bn", ":BufferLineCycleNext<CR>", desc = "Next", remap = false },
  { "<leader>bp", ":BufferLineCyclePrev<CR>", desc = "Previous", remap = false },
  { "<leader>bs", ":BufferLinePick<CR>", desc = "Select", remap = false },
})

which_key.add({
  { "<leader>f", group = "Find", remap = false },
  { "<leader>f/", '<cmd>lua require("telescope.builtin").current_buffer_fuzzy_find()<CR>', desc = "Buffer Grep", remap = false },
  { "<leader>fa", "<cmd>:Telescope telescope-tabs list_tab<CR>", desc = "Tabs", remap = false },
  { "<leader>fb", '<cmd>lua require("telescope.builtin").buffers()<CR>', desc = "Buffer", remap = false },
  { "<leader>fc", "<cmd>:Cheatsheet<CR>", desc = "Cheatsheet", remap = false },
  { "<leader>fd", "<cmd>:Telescope lsp_document_symbols<CR>", desc = "Document Symbols", remap = false },
  { "<leader>ff", '<cmd>lua require("telescope.builtin").find_files({ hidden = true, find_command = { "rg", "--files", "--hidden", "--follow", "--ignore-file", "~/.vimignore" } })<CR>', desc = "File", remap = false },
  { "<leader>fg", '<cmd>lua require("telescope.builtin").live_grep()<CR>', desc = "Grep", remap = false },
  { "<leader>fl", '<cmd>lua require("telescope").extensions.luasnip.luasnip{}<CR>', desc = "Snippets", remap = false },
  { "<leader>fp", "<cmd>:Telescope lazy<CR>", desc = "Lazy", remap = false },
  { "<leader>fr", '<cmd>lua require("telescope").extensions.repo.list{fd_opts=[[--ignore-file=~/.config/nvim/lua/plugins/telescope_fdignore]]}<CR>', desc = "Repos", remap = false },
  { "<leader>fs", '<cmd>lua require("telescope.builtin").spell_suggest()<CR>', desc = "Spelling", remap = false },
  { "<leader>ft", '<cmd>lua require("telescope.builtin").treesitter()<CR>', desc = "Treesitter", remap = false },
  { "<leader>fy", '<cmd>lua require("telescope").extensions.neoclip.default()<CR>', desc = "Yank", remap = false },
})

which_key.add({
  { "<leader>fF", group = "File Kinds", remap = false },
  { "<leader>fFb", "<cmd>:Telescope file_browser<CR>", desc = "File Browser", remap = false },
  { "<leader>fFg", '<cmd>lua require("telescope.builtin").git_files()<CR>', desc = "Git Files", remap = false },
  { "<leader>fFo", '<cmd>lua require("telescope.builtin").oldfiles()<CR>', desc = "Old Files", remap = false },
})

which_key.add({
  { "<leader>fh", group = "History", remap = false },
  { "<leader>fhc", '<cmd>lua require("telescope.builtin").command_history()<CR>', desc = "Commands", remap = false },
  { "<leader>fhs", '<cmd>lua require("telescope.builtin").search_history()<CR>', desc = "Searches", remap = false },
})

which_key.add({
  { "<leader>g", group = "Git", remap = false },
  { "<leader>ga", ":Git commit --amend<CR>", desc = "Amend", remap = false },
  { "<leader>gb", ":GBrowse<CR>", desc = "Browse on GitHub", remap = false },
  { "<leader>gc", ":Git commit --verbose<CR>", desc = "Commit", remap = false },
  { "<leader>gm", ":GitMessenger<CR>", desc = "Show Message", remap = false },
  { "<leader>gw", ":Gwrite<CR>", desc = "Write", remap = false },
})

which_key.add({
  { "<leader>l", group = "Language / LSP", remap = false },
  { "<leader>ld", "<cmd>:Telescope lsp_document_symbols<CR>", desc = "Document Symbols", remap = false },
  { "<leader>lf", "<cmd>lua vim.lsp.buf.formatting()<CR>", desc = "Format", remap = false },
  { "<leader>lh", "<cmd>lua vim.lsp.buf.hover()<CR>", desc = "Hover", remap = false },
  { "<leader>lj", '<cmd>lua vim.diagnostic.goto_next({ border = "rounded" })<CR>', desc = "GoTo Next", remap = false },
  { "<leader>lk", '<cmd>lua vim.diagnostic.goto_prev({ border = "rounded" })<CR>', desc = "GoTo Previous", remap = false },
  { "<leader>lo", '<cmd>lua vim.diagnostic.open_float(0, { scope = "line", border = "single" })<CR>', desc = "Open", remap = false },
  { "<leader>lr", "<cmd>lua vim.lsp.buf.references()<CR>", desc = "References", remap = false },
  { "<leader>ls", "<cmd>lua vim.lsp.buf.signature_help()<CR>", desc = "Signature Help", remap = false },
})

which_key.add({
  { "<leader>lg", group = "GoTo", remap = false },
  { "<leader>lgd", "<cmd>lua vim.lsp.buf.declaration()<CR>", desc = "GoTo Declaration", remap = false },
  { "<leader>lgf", "<cmd>lua vim.lsp.buf.definition()<CR>", desc = "GoTo Definition", remap = false },
  { "<leader>lgi", "<cmd>lua vim.lsp.buf.implementation()<CR>", desc = "GoTo Implementation", remap = false },
})

which_key.add({
  { "<leader>w", group = "Window", remap = false },
  { "<leader>wc", "<C-w>c", desc = "Close", remap = false },
  { "<leader>wh", "<C-w>h", desc = "Left", remap = false },
  { "<leader>wj", "<C-w>j", desc = "Below", remap = false },
  { "<leader>wk", "<C-w>k", desc = "Above", remap = false },
  { "<leader>wl", "<C-w>l", desc = "Right", remap = false },
  { "<leader>wq", "<C-w>q", desc = "Quit", remap = false },
})

which_key.add({
  { "<leader>wn", group = "New", remap = false },
  { "<leader>wnh", ":split", desc = "New Horizontal Split", remap = false },
  { "<leader>wnv", ":vsplit", desc = "New Vertical Split", remap = false },
})

which_key.add({
  { "<leader>ws", group = "Size", remap = false },
  { "<leader>wsh", ":vertical resize -2<CR>", desc = "Resize Narrower", remap = false },
  { "<leader>wsj", ":resize +2<CR>", desc = "Resize Taller", remap = false },
  { "<leader>wsk", ":resize -2<CR>", desc = "Resize Shorter", remap = false },
  { "<leader>wsl", ":vertical resize +2<CR>", desc = "Resize Wider", remap = false },
})

which_key.add({
  { "<leader>t", ":TroubleToggle<CR>", desc = "Trouble", remap = false },
})

which_key.add({
  { "<leader>v", group = "View", remap = false },
  { "<leader>vs", "<cmd>AerialToggle!<CR>", desc = "Toggle Aerial", remap = false },
})
