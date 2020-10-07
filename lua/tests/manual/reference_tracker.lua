
-- local actions = require('telescope.actions')
-- local utils = require('telescope.utils')
require('telescope')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local log = require('telescope.log')

local real_opts = setmetatable({}, { __mode = 'v' })
local opts = setmetatable({}, { 
  __index = function(t, k) log.debug("accessing:", k); return real_opts[k] end,
  __newindex = function(t, k, v) log.debug("setting:", k, v); real_opts[k] = v end
})

opts.entry_maker = opts.entry_maker or make_entry.gen_from_file()
if opts.cwd then
  opts.cwd = vim.fn.expand(opts.cwd)
end

-- local get_finder_opts = function(opts)
--   local t = {}
--   t.entry_maker = table.pop(opts, 'entry_maker')
--   return t
-- end

-- local finder_opts = get_finder_opts(opts)
-- assert(not opts.entry_maker)

local picker_config = {
  prompt    = 'Git File',
  finder    = finders.new_oneshot_job(
    { "git", "ls-files", "-o", "--exclude-standard", "-c" }
    , opts
  ),
  -- previewer = previewers.cat.new(opts),
  -- sorter    = sorters.get_fuzzy_file(opts),
  -- sorter    = sorters.get_fuzzy_file(),
}

log.debug("Done with config")

local x = pickers.new(picker_config)
x:find()
x = nil
