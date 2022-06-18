local async = require "plenary.async"
local async_job = require "telescope._"
local LinesPipe = require("telescope._").LinesPipe
local make_entry = require "telescope.make_entry"

local function config_from_opts(opts)
  opts = opts or {}
  return {
    entry_maker = opts.entry_maker or make_entry.gen_from_string,
    cwd = opts.cwd,
    env = opts.env,
    fn_command = assert(opts.fn_command, "Must pass 'fn_command'"),
    results = opts.results or {},
  }
end

local function finder_factory(opts)
  local config = config_from_opts(opts)
  -- TODO is it better to work on a copy?
  local cached = config.results
  local job, stdout

  local function start_job_once()
    start_job_once = function() end
    local call = config.fn_command()
    stdout = LinesPipe()
    job = async_job.spawn {
      command = call.command,
      args = call.args,
      cwd = config.cwd,
      env = config.env,
      stdout = stdout,
    }
  end

  --[[
  -- A finder is a callable with arguments (prompt, process_result, process_complete).
  -- In general, the results it produces can depend on prompt.
  -- For this one-shot finder here the results dont depend on prompt.
  -- The user searches the results only based on fuzzy matching.
  -- A finder callable should yield and not block too often.
  -- Call process_result(entry) to add a new entry.
  -- Exit early if process_result() returns true.
  -- Always call process_complete() before exiting.
  -- The picker relies on finder to reproduce all the same entries again when the prompt changes.
  --]]
  local function produce_entries(_, _, process_result, process_complete)
    start_job_once()

    for _, entry in ipairs(cached) do
      -- TODO ok something is very wrong here, scheduler waits until we are on the main thread? then we always need it
      -- or should process_result do it itself, because they want to call vim.api stuff
      -- original did something like every 1000 iterations, but that makes no sense because you dont know how fast is your command
      -- how does this relate to await_schedule()? ah the same. just an alias
      async.util.scheduler()
      if process_result(entry) then
        process_complete()
        return
      end
    end

    if stdout then
      for line in stdout:iter(false) do
        local entry = config.entry_maker(line)
        table.insert(cached, entry)
        async.util.scheduler()
        if process_result(entry) then
          process_complete()
          return
        end
      end
      stdout = nil
    end

    process_complete()
  end

  local function close()
    if job then
      job:close()
      job = nil
    end
  end

  local finder = setmetatable({ close = close }, { __call = produce_entries })
  return finder
end

return finder_factory
