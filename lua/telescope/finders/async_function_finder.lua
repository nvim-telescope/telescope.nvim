local async_lib = require "plenary.async_lib"
local async = async_lib.async
local await = async_lib.await
local void = async_lib.void

local make_entry = require "telescope.make_entry"

local function default_make_results(results_maker, entry_maker)
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

return function(opts)
  local results_maker
  local entry_maker
  local make_results
  if type(opts) == "function" then
    results_maker = opts
    entry_maker = make_entry.gen_from_string()
    make_results = default_make_results
  else
    results_maker = opts.results_maker
    entry_maker = opts.entry_maker or make_entry.gen_from_string()
    make_results = opts.make_results or default_make_results
  end

  return setmetatable({
    results = {},
    close = function() end,
  }, {
    __call = void(async(function(self, _, process_result, process_complete)
      self.results = make_results(results_maker, entry_maker)
      for i, v in ipairs(self.results) do
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
