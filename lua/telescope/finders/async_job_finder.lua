local async_job = require("telescope.async_job")
local LinesPipe = async_job.LinesPipe

local make_entry = require("telescope.make_entry")
local log = require("telescope.log")

return function(opts)
  log.trace("Creating async_job:", opts)
  assert(not opts.writer, "async_job_finder: `writer` is not implemented")
  local entry_maker = opts.entry_maker or make_entry.gen_from_string(opts)

  local job

  local callable = function(_, prompt, process_result, process_complete)
    if job then
      job:close()
    end

    local args = opts.command_generator(prompt)
    if not args then
      process_complete()
      return
    end

    local stdout = LinesPipe()
    job = async_job.spawn({
      command = table.remove(args, 1),
      args = args,
      cwd = opts.cwd,
      env = opts.env,
      stdout = stdout,
    })

    local line_num = 0
    for line in stdout:iter() do
      line_num = line_num + 1
      local entry = entry_maker(line)
      if entry then
        entry.index = line_num
      end
      process_result(entry)
    end

    process_complete()
  end

  return setmetatable({
    close = function()
      if job then
        job:close()
      end
    end,
  }, {
    __call = callable,
  })
end
