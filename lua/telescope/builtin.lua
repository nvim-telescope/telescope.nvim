--[[
A collection of builtin pipelines for telesceope.

Meant for both example and for easy startup.
--]]

local builtin = {}

builtin.git_files = function(_)
  -- TODO: Auto select bottom row
  -- TODO: filter out results when they don't match at all anymore.

  local telescope = require('telescope')

  local file_finder = telescope.finders.new {
    static = true,

    fn_command = function() return 'git ls-files' end,
  }

  local file_previewer = telescope.previewers.vim_buffer

  local file_picker = telescope.pickers.new {
    previewer = file_previewer
  }

  -- local file_sorter = telescope.sorters.get_ngram_sorter()
  -- local file_sorter = require('telescope.sorters').get_levenshtein_sorter()
  local file_sorter = telescope.sorters.get_norcalli_sorter()

  file_picker:find {
    prompt = 'Simple File',
    finder = file_finder,
    sorter = file_sorter,
  }
end


return builtin
