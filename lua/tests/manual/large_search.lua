require('plenary.reload').reload_module('plenary')
require('plenary.reload').reload_module('telescope')

require('telescope')

profiler = require('plenary.profile.lua_profiler')

local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local builtin = require('telescope.builtin')

PERF_DEBUG = nil
if PERF_DEBUG then
  vim.api.nvim_buf_set_lines(PERF_DEBUG, 0, -1, false, {})
end

local cwd = vim.fn.expand("~/build/neovim")

profiler.start()

-- pickers.new {
--   prompt = 'Large search',
--   finder = finders.new_oneshot_job(
--     {"fdfind"},
--     {
--       cwd = cwd,
--       entry_maker = make_entry.gen_from_file {cwd = cwd},
--       -- disable_devicons = true,
--       -- maximum_results = 1000,
--     }
--   ),
--   sorter = sorters.get_fuzzy_file(),
--   previewer = previewers.cat.new{cwd = cwd},
-- }:find()
builtin.live_grep {
  max_results = 10,
  cwd = cwd,
}

--[[
profiler.stop()
profiler.report('/home/tj/tmp/profiler_score.txt')
--]]
