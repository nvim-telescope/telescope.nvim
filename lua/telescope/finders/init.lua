
local JobFinder = require('telescope.finders.job')
local OneshotFinder = require('telescope.finders.oneshot')
local StaticFinder = require('telescope.finders.static')

local finders = {}

--- Return a new Finder
--
-- Use at your own risk.
-- This opts dictionary is likely to change, but you are welcome to use it right now.
-- I will try not to change it needlessly, but I will change it sometimes and I won't feel bad.
finders._new = function(opts)
  if opts.results then
    print("finder.new is deprecated with `results`. You should use `finder.new_table`")
    return StaticFinder:new(opts)
  end

  return JobFinder:new(opts)
end

finders.new_job = function(command_generator, entry_maker, maximum_results)
  return JobFinder:new {
    fn_command = function(_, prompt)
      local command_list = command_generator(prompt)
      if command_list == nil then
        return nil
      end

      local command = table.remove(command_list, 1)

      return {
        command = command,
        args = command_list,
      }
    end,

    entry_maker = entry_maker,
    maximum_results = maximum_results,
  }
end

---@param command_list string[] Command list to execute.
---@param opts table
---         @key entry_maker function Optional: function(line: string) => table
---         @key cwd string
finders.new_oneshot_job = function(command_list, opts)
  opts = opts or {}

  command_list = vim.deepcopy(command_list)

  local command = table.remove(command_list, 1)

  return OneshotFinder:new {
    entry_maker = opts.entry_maker,

    cwd = opts.cwd,
    maximum_results = opts.maximum_results,

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
  return StaticFinder:new(t)
end

return finders
