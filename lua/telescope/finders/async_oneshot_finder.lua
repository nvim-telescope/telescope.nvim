local async_lib = require('plenary.async_lib')
local async = async_lib.async
local await = async_lib.await
local void = async_lib.void

local AWAITABLE = 1000

local make_entry = require('telescope.make_entry')

local Job = require('plenary.job')

return function(opts)
  opts = opts or {}

  local entry_maker = opts.entry_maker or make_entry.from_string
  local cwd = opts.cwd
  local fn_command = assert(opts.fn_command, "Must pass `fn_command`")

  local results = {}
  local num_results = 0

  local job_started = false
  local job_completed = false
  return setmetatable({
    close = function() results = {}; job_started = false end,
    results = results,
  }, {
    __call = void(async(function(_, prompt, process_result, process_complete)
      if not job_started then
        local job_opts = fn_command()

        local writer
        if job_opts.writer and Job.is_job(job_opts.writer) then
          writer = job_opts.writer
        elseif job_opts.writer then
          writer = Job:new(job_opts.writer)
        end

        local job = Job:new {
          command = job_opts.command,
          args = job_opts.args,
          cwd = job_opts.cwd or cwd,
          maximum_results = opts.maximum_results,
          writer = writer,
          enable_recording = false,

          on_stdout = vim.schedule_wrap(function(_, line)
            num_results = num_results + 1

            local v = entry_maker(line)
            results[num_results] = v
            process_result(v)
          end),

          on_exit = function()
            process_complete()
            job_completed = true
          end,
        }

        job:start()
        job_started = true
      end

      local current_count = num_results
      for index = 1, current_count do
        if process_result(results[index]) then
          break
        end

        if index % AWAITABLE == 0 then
          await(async_lib.scheduler())
        end
      end

      if job_completed then
        process_complete()
      end
    end)),
  })
end
