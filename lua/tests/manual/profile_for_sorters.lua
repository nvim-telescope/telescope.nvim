-- TODO: Add a ladder test.
--          1, 2, 4, 8, 16, 32 attempts

RELOAD('plenary')
-- RELOAD('telescope')

local profiler = require('plenary.profile.lua_profiler')
local Job = require('plenary.job')

BIG_LIST = nil
BIG_LIST = BIG_LIST or Job:new { command = 'fdfind', cwd = '~/build/' }:sync()
print(#BIG_LIST)

local do_profile = true
local sorter_to_test = require('telescope.sorters').get_fuzzy_file()

local strings_to_test = { "", "ev", "eval.c", "neovim/eval.c" }

if do_profile then
  profiler.start()
end

local first_results = setmetatable({}, {
  __index = function(t, k)
    local obj = {}
    rawset(t, k, obj)
    return obj
  end
})

local second_results = {}

local do_iterations = function(num)
  local start
  for _, prompt in ipairs(strings_to_test) do
    start = vim.fn.reltime()

    for _ = 1, num do
      for _, v in ipairs(BIG_LIST) do
        sorter_to_test:score(prompt, v)
      end
    end
    -- print("First  Time: ", vim.fn.reltimestr(vim.fn.reltime(start)), num, prompt)
    table.insert(first_results[prompt], vim.fn.reltimestr(vim.fn.reltime(start)))

    start = vim.fn.reltime()
    for _ = 1, num do
      for _, v in ipairs(BIG_LIST) do
        sorter_to_test:score(prompt, v)
      end
    end

    -- print("Second Time: ", vim.fn.reltimestr(vim.fn.reltime(start)), num, prompt)
    table.insert(second_results, vim.fn.reltimestr(vim.fn.reltime(start)))
  end
end

do_iterations(1)
-- do_iterations(2)
-- do_iterations(4)
-- do_iterations(8)
-- do_iterations(16)
-- do_iterations(32)

print(vim.inspect(first_results))

if do_profile then
  profiler.stop()
  profiler.report('/home/tj/tmp/profiler_score.txt')
end

