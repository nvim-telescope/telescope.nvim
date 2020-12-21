pcall(function() RELOAD('telescope') end)

local builtin = require('telescope.builtin')
local tester = require('telescope.pickers._tests')

local key = 'find_files'
local input =  'fixtures/file<c-p>'
local expected = 'lua/tests/fixtures/file_2.txt'
local get_actual = function()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
end

-- local on_complete_item = tester.picker_feed(input, expected, get_actual, true)
-- 
-- builtin[key] {
--   on_complete = { on_complete_item }
-- }

tester.builtin_picker('find_files', 'fixtures/file<c-p>', 'lua/tests/fixtures/file_2.txt', function()
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
end, {
  debug = false,
})

