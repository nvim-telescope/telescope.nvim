local _async = require "telescope._async"

local async_job = require "telescope.async_job"
local make_entry = require "telescope.make_entry"

local LinesPipe = async_job.LinesPipe

return function(opts)
  opts = opts or {}

  local entry_maker = opts.entry_maker or make_entry.gen_from_string(opts)
  local fn_command = assert(opts.fn_command, "Must pass `fn_command`")

  local results = vim.nonnil(opts.results, {})
  local num_results = #results

  local lines -- the lines of the command's output, once it has been started
  local loaded = false
  local job

  return setmetatable({
    close = function()
      if job then
        job:close()
      end
    end,
    results = results,
    entry_maker = entry_maker,
    -- results don't depend on the prompt (allows narrowing, see `Picker:_narrowed_candidates`)
    prompt_independent = true,
  }, {
    -- Each find processes the results loaded so far and then loads the rest. A find is cancelled
    -- (its task closed) only while it waits, so `results` stays consistent and the next find
    -- continues loading where the cancelled one stopped.
    __call = function(_, _, process_result, process_complete)
      if not lines then
        local job_opts = fn_command()
        local stdout = LinesPipe()
        job = async_job.spawn {
          command = job_opts.command,
          args = job_opts.args,
          cwd = opts.cwd,
          env = opts.env,
          stdout = stdout,
        }
        lines = stdout:iter { split_char = opts.split_char }
      end

      _async.process_list(results, num_results, process_result)
      if not loaded then
        for line in lines do
          local n = num_results + 1
          local entry = entry_maker(line)
          if entry then
            entry.index = n
          end
          results[n], num_results = entry, n
          process_result(entry)
          if n % 1000 == 0 then -- as `_async.process_list`
            _async.yield()
          end
        end
        loaded = true
      end
      process_complete()
    end,
  })
end
