local tester = require('telescope.pickers._test')

tester.builtin_picker('find_files', 'README.md', {
  post_close = {
    {'README.md', function() return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.") end },
  }
})
