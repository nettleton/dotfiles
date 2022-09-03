local which_key_ok, which_key = pcall(require, "which-key")
if not which_key_ok then
  vim.notify("require('which-key') failed")
  return
end

which_key.setup {
  -- https://github.com/folke/which-key.nvim/
}
