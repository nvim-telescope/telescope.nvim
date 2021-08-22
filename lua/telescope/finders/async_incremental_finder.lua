local make_entry = require "telescope.make_entry"
local async = require "plenary.async"

local await_count = 1000

return function(opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")

  local entry_maker = opts.entry_maker or make_entry.gen_from_string()
  local fn = assert(opts.fn, "Must pass `fn`")
  local iterator

  local results = {}
  local num_results = 0

  local fn_started = false
  local fn_completed = false

  return setmetatable({
    results = results,
    close = function() end,
  }, {
    __call = function(_, _, process_result, process_complete)
      if not fn_started then
        iterator = fn()
        fn_started = true
      end

      if not fn_completed then
        for _, result in iterator do
          num_results = num_results + 1

          if num_results % await_count then
            async.util.scheduler()
          end

          local v = entry_maker(result)
          results[num_results] = v
          process_result(v)
        end
        process_complete()
        fn_completed = true
        return
      end

      local current_count = num_results
      for index = 1, current_count do
        -- TODO: Figure out scheduling...
        if index % await_count then
          async.util.scheduler()
        end

        if process_result(results[index]) then
          break
        end
      end

      process_complete()
    end,
  })
end
