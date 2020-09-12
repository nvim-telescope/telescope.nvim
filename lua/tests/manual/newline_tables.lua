require('plenary.reload').reload_module('telescope')

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local my_list = {'a', 'b', 'c'}

pickers.new({
  prompt    = 'Telescope Builtin',
  finder    = finders.new_table {
    results = my_list,
  },
  sorter    = sorters.get_generic_fuzzy_sorter(),
}):find()
