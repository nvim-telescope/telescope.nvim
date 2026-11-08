local make_entry = require "telescope.make_entry"

local async_static_finder = require "telescope.finders.async_static_finder"
local async_oneshot_finder = require "telescope.finders.async_oneshot_finder"
local async_job_finder = require "telescope.finders.async_job_finder"

local finders = {}

local _callable_obj = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, ...)
    return t:_find(...)
  end

  obj.close = function() end

  return obj
end

local DynamicFinder = _callable_obj()

function DynamicFinder:new(opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")
  assert(not opts.static, "`static` should be used with finder.new_oneshot_job")

  local obj = setmetatable({
    curr_buf = opts.curr_buf,
    fn = opts.fn,
    entry_maker = opts.entry_maker or make_entry.gen_from_string(opts),
  }, self)

  return obj
end

function DynamicFinder:_find(prompt, process_result, process_complete)
  local results = self.fn(prompt)

  local result_num = 0
  for _, result in ipairs(results) do
    result_num = result_num + 1
    local entry = self.entry_maker(result)
    if entry then
      entry.index = result_num
    end
    if process_result(entry) then
      return
    end
  end

  process_complete()
end

finders.new_async_job = function(opts)
  return async_job_finder(opts)
end

finders.new_job = function(command_generator, entry_maker, _, cwd)
  return async_job_finder {
    command_generator = command_generator,
    entry_maker = entry_maker,
    cwd = cwd,
  }
end

--- One shot job
---@param command_list string[]: Command list to execute.
---@param opts table: stuff
--         @key entry_maker function Optional: function(line: string) => table
--         @key cwd string
finders.new_oneshot_job = function(command_list, opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")

  command_list = vim.deepcopy(command_list)
  local command = table.remove(command_list, 1)

  return async_oneshot_finder {
    entry_maker = opts.entry_maker or make_entry.gen_from_string(opts),

    cwd = opts.cwd,
    maximum_results = opts.maximum_results,
    split_char = opts.split_char,

    fn_command = function()
      return {
        command = command,
        args = command_list,
      }
    end,
  }
end

--- Used to create a finder for a Lua table.
-- If you only pass a table of results, then it will use that as the entries.
--
-- If you pass a table, and then a function, it's used as:
--  results table, the results to run on
--  entry_maker function, the function to convert results to entries.
finders.new_table = function(t)
  return async_static_finder(t)
end

--- Used to create a finder from a function.
--
---@param opts table: stuff
--         @key fn function() => list[string]
--         @key entry_maker function Optional: function(line: string) => table
finders.new_dynamic = function(opts)
  return DynamicFinder:new(opts)
end

return finders
