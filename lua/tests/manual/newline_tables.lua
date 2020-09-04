require('plenary.reload').reload_module('telescope')

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')


pickers.new({
  prompt    = 'Telescope Builtin',
  finder    = finders.new_table {
    results = {"hello\nworld", "other", "item"},
    entry_maker = false and function(line)
      return {
        value = line,
        ordinal = line,
        display = "wow: // " .. line,
      }
    end,
  },
  sorter    = sorters.get_norcalli_sorter(),
}):find()
