require('plenary.reload').reload_module('plenary')
require('plenary.reload').reload_module('telescope')

--[[

Goals:
1. Easily test a sorter and finder to make sure we get all the results we need.

--]]

local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local EntryManager = require('telescope.entry_manager')

local find_and_sort_test = function(prompt, f, s)
  local info = {}

  local start = vim.loop.hrtime()

  info.filtered = 0
  info.added = 0
  info.scoring_time = 0
  info.set_entry = 0

  local entry_manager = EntryManager:new(25, function()
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
    info.time = (vim.loop.hrtime() - start) / 1e9

    info.total = info.filtered + info.added
    completed = true
  end

  f(prompt, process_result, process_complete)

  -- Wait until we're done to return
  vim.wait(5000, function() return completed end, 10)

  return entry_manager, info
end

local info_to_csv = function(info, filename)
  local writer = io.open(filename, "a")

  writer:write(string.format("%.8f", info.scoring_time) .. "\t")
  writer:write(string.format("%.8f", info.time) .. "\t")
  writer:write(info.looped .. "\t")
  writer:write(info.filtered .. "\t")
  writer:write(info.added .. "\t")
  writer:write(info.inserted .. "\t")
  writer:write(info.total .. "\t")
  writer:write(info.set_entry .. "\t")
  writer:write(string.format("%.0f", collectgarbage("count")) .. "\t")
  writer:write("\n")

  writer:close()
end


local cwd = vim.fn.expand("~/build/neovim")

collectgarbage("collect")
for _ = 1, 1 do

  -- local s = sorters.get_fuzzy_file()
  local s = sorters.get_generic_fuzzy_sorter()
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
    s
  )

  -- print(vim.inspect(res:get_entry(1)))
  -- print(vim.inspect(info))

  info_to_csv(info, "/home/tj/tmp/profile.csv")

  collectgarbage("collect")
end
-- No skip: 2,206,186
-- Ya skip:     2,133
