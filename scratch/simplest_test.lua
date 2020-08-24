require('plenary.reload').reload_module('telescope')

local telescope = require('telescope')

-- What is a finder?
--  Finders return a list of stuff that you want to fuzzy look through.
--  Finders can be static or not.
--  Static finders just return a list that never changes
--  Otherwise they return a new list on each input, you should handle them async.
local file_finder = telescope.finders.new {
  static = true,

  fn_command = function() return 'git ls-files' end,
}

local file_previewer = telescope.previewers.vim_buffer_or_bat

local file_picker = telescope.pickers.new {
  previewer = file_previewer
}

-- local file_sorter = telescope.sorters.get_ngram_sorter()
-- local file_sorter = require('telescope.sorters').get_levenshtein_sorter()
local file_sorter = require('telescope.sorters').get_norcalli_sorter()

file_picker:find {
  prompt = 'Simple File',
  finder = file_finder,
  sorter = file_sorter,
}
