require('Comment').setup({
  ---LHS of toggle mappings in NORMAL mode
  toggler = {
      ---Line-comment toggle keymap
      line = '<leader>cl',
      ---Block-comment toggle keymap
      block = '<leader>cb',
  },
  ---LHS of operator-pending mappings in NORMAL and VISUAL mode
  opleader = {
      ---Line-comment keymap
      line = '<leader>cl',
      ---Block-comment keymap
      block = '<leader>cb',
  },
  ---LHS of extra mappings
  extra = {
      ---Add comment on the line above
      above = '<leader>c0',
      ---Add comment on the line below
      below = '<leader>co',
      ---Add comment at the end of line
      eol = '<leader>ca',
  },
})
