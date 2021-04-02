R('telescope')
R('plenary')

local Job = require('plenary.job')

local async_static_finder = require('telescope.finders.async_static_finder')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values
local make_entry = require('telescope.make_entry')

local sorters = require('telescope.sorters')
local cwd = vim.fn.expand("~/")


RESULTS = nil
if not RESULTS then
  RESULTS = Job:new { "rg", "--files", cwd = cwd, }:sync()
end

local f = async_static_finder {
  results = RESULTS,
  entry_maker = make_entry.gen_from_file { cwd = cwd },
}

pickers.new({ cwd = cwd}, {
  prompt_title = 'Async Finder',
  finder = f,
  sorter = conf.file_sorter({}),
  is_async = true,
  previewer = conf.file_previewer({ cwd = cwd }),
  -- previewer = false,
}):find()
