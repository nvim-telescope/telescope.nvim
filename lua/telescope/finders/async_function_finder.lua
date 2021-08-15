local async_lib = require "plenary.async_lib"
local async = async_lib.async
local await = async_lib.await
local void = async_lib.void

local make_entry = require "telescope.make_entry"

return function(opts)
  local results_maker
  local entry_maker
  if type(opts) == 'function' then
    results_maker = opts
    entry_maker = make_entry.gen_from_string()
  else
    results_maker = opts.results_maker
    entry_maker = opts.entry_maker or make_entry.gen_from_string()
  end


  local function make_results()
    local input_results = results_maker()
    local results = {}
    for k, v in ipairs(input_results) do
      local entry = entry_maker(v)

      if entry then
        entry.index = k
        table.insert(results, entry)
      end
    end
    return results
  end

  return setmetatable({
    results = {},
    close = function() end,
  }, {
    __call = void(async(function(table, _, process_result, process_complete)
      table.results = make_results()
      for i, v in ipairs(table.results) do
        if process_result(v) then
          break
        end

        if i % 1000 == 0 then
          await(async_lib.scheduler())
        end
      end

      process_complete()
    end)),
  })
end
