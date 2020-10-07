require('plenary.reload').reload_module('telescope')

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local previewers = require('telescope.previewers')
local make_entry = require('telescope.make_entry')

local my_list = {
  'lua/telescope/WIP.lua',
  'lua/telescope/actions.lua',
  'lua/telescope/builtin.lua',
}

local opts = {}

pickers.new(opts, {
  prompt    = 'Telescope Builtin',
  finder    = finders.new_table {
    results = my_list,
  },
  sorter    = sorters.get_generic_fuzzy_sorter(),
  previewer = previewers.cat.new(opts),
}):find()
