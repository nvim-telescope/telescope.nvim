require('plenary.reload').reload_module('telescope')

--[[

Goals:
1. Easily test a sorter and finder to make sure we get all the results we need.

--]]

local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local find_and_sort_test = function(prompt, f, s)
  local info = {}

  info.start = vim.loop.hrtime()

  info.filtered = 0
  info.added = 0
  info.scoring_time = 0
  info.set_entry = 0

  local entry_manager = pickers.entry_manager(25, function()
    info.set_entry = info.set_entry + 1
  end, info)

  local completed = false

  local process_result = function(entry)
    local score_start = vim.loop.hrtime()
    local score = s:score(prompt, entry)
    info.scoring_time = info.scoring_time + (vim.loop.hrtime() - score_start) / 1e9

    -- Filter these out here.
    if score == -1 then
      info.filtered = info.filtered + 1
      return
    end

    info.added = info.added + 1
    entry_manager:add_entry(
      s:score(prompt, entry),
      entry
    )
  end

  local process_complete = function()
    info.finish = vim.loop.hrtime()
    info.time = (info.finish - info.start) / 1e9

    info.total = info.filtered + info.added
    completed = true
  end

  f(prompt, process_result, process_complete)

  -- Wait until we're done to return
  vim.wait(5000, function() return completed end, 10)

  return entry_manager, info
end

local cwd = vim.fn.expand("~/")

local finder = finders.new_oneshot_job(
  {"fdfind"},
  {
    cwd = cwd,
    entry_maker = make_entry.gen_from_file {cwd = cwd},
    -- disable_devicons = true,
    -- maximum_results = 1000,
  }
)

local res, info = find_and_sort_test(
  "pickers.lua",
  finder,
  sorters.get_generic_fuzzy_sorter()
)

print(vim.inspect(res:get_entry(1)))
print(vim.inspect(info))

-- No skip: 2,206,186
-- Ya skip:     2,133
