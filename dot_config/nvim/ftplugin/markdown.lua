-- set conceallevel for markdown files
vim.opt.conceallevel = 2

-- Extract reminders from markdown files
vim.api.nvim_create_user_command("ExtractReminders", function()
  local filenameExpanded = vim.fn.expand('%:p')
  if string.find(filenameExpanded, "notes") then
    vim.fn.system("extractReminders \"" .. filenameExpanded .. "\"")
    vim.api.nvim_command("checktime")
  end
end, { nargs = 0 })

-- Map ExtractReminders to file write events
vim.api.nvim_create_autocmd({"BufWritePost"}, {
  pattern = {"*.md"},
  command = "lua vim.api.nvim_command('ExtractReminders')"
})

vim.api.nvim_create_user_command("PublishPrayer", function()
  local filenameExpanded = vim.fn.expand('%')
  local date = filenameExpanded:match('%d+-%d+-%d+')
  local cmd = "zk pp " .. date
  vim.fn.system(cmd)
  vim.api.nvim_command("checktime")
end, { nargs = 0 })

vim.api.nvim_create_autocmd({"BufWritePost"}, {
  pattern = {"*/zk/elder/prayers/*.md"},
  command = "lua vim.api.nvim_command('PublishPrayer')"
})
