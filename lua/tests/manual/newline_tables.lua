RELOAD('telescope')

local actions = require('telescope.actions')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')


pickers.new({
  prompt    = 'Telescope Builtin',
  finder    = finders.new_table({"hello\nworld", "other", "item"}),
  sorter    = sorters.get_norcalli_sorter(),
}):find()
