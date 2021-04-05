local log = require('telescope.log')
local Job = require('plenary.job')

local async_lib = require('plenary.async_lib')
local async = async_lib.async
-- local await = async_lib.await
local void = async_lib.void

local make_entry = require('telescope.make_entry')

return function(opts)
  local entry_maker = opts.entry_maker or make_entry.gen_from_string()
  local fn_command = function(prompt)
    local command_list = opts.command_generator(prompt)
    if command_list == nil then
      return nil
    end

    local command = table.remove(command_list, 1)

    return {
      command = command,
      args = command_list,
    }
  end

  local job
  return setmetatable({
    close = function() end,
  }, {
    __call = void(async(function(prompt, process_result, process_complete)
      print("are we callin anything?", job)
      if job and not job.is_shutdown then
        log.debug("Shutting down old job")
        job:shutdown()
      end

      local job_opts = fn_command(prompt)
      if not job_opts then return end

      local writer = nil
      if job_opts.writer and Job.is_job(job_opts.writer) then
        writer = job_opts.writer
      elseif opts.writer then
        writer = Job:new(job_opts.writer)
      end

      job = Job:new {
        command = job_opts.command,
        args = job_opts.args,
        cwd = job_opts.cwd or opts.cwd,
        maximum_results = opts.maximum_results,
        writer = writer,
        enable_recording = false,

        on_stdout = vim.schedule_wrap(function(_, line)
          if not line or line == "" then
            return
          end

          -- TODO: shutdown job here.
          process_result(entry_maker(line))
        end),

        on_exit = function()
          process_complete()
        end,
      }

      job:start()
    end)),
  })
end
