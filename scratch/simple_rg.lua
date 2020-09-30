local telescope = require('telescope')

-- Uhh, finder should probably just GET the results
-- and then update some table.
-- When updating the table, we should call filter on those items
-- and then only display ones that pass the filter
local rg_finder = telescope.finders.new {
  fn_command = function(_, prompt)
    return string.format('rg --vimgrep %s', prompt)
  end,

  responsive = false
}

local p = telescope.pickers.new {
  previewer = telescope.previewers.vim_buffer
}
p:find {
  prompt = 'grep',
  finder = rg_finder
}


