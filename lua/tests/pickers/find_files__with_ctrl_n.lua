local tester = require('telescope.pickers._test')
local helper = require('telescope.pickers._test_helpers')

tester.builtin_picker('find_files', 'fixtures/file<c-p>', {
  post_close = {
    { 'lua/tests/fixtures/file_2.txt', helper.get_file }
  },
})

