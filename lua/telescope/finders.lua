local Job = require('plenary.job')

local make_entry = require('telescope.make_entry')
local log = require('telescope.log')

local finders = {}

local _callable_obj = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, ...) return t:_find(...) end

  return obj
end


--[[ =============================================================

    JobFinder

Uses an external Job to get results. Processes results as they arrive.

For more information about how Jobs are implemented, checkout 'plenary.job'

-- ============================================================= ]]
local JobFinder = _callable_obj()

--- Create a new finder command
---
---@param opts table Keys:
--     fn_command function The function to call
function JobFinder:new(opts)
  opts = opts or {}

> assert(not opts.results, "`results` should be used with finder.new_table")
  assert(not opts.static, "`static` should be used with finder.new_oneshot_job")

  local obj = setmetatable({
    entry_maker = opts.entry_maker or make_entry.from_string,
    fn_command = opts.fn_command,
    cwd = opts.cwd,
    writer = opts.writer,

    -- Maximum number of results to process.
    --  Particularly useful for live updating large queries.
    maximum_results = opts.maximum_results,
  }, self)

  return obj
end

function JobFinder:_find(prompt, process_result, process_complete)
  log.trace("Finding...")

  if self.job and not self.job.is_shutdown then
    log.debug("Shutting down old job")
    self.job:shutdown()
  end

  local on_output = function(_, line, _)
    if not line or line == "" then
      return
    end

    if self.entry_maker then
      line = self.entry_maker(line)
    end

    process_result(line)
  end

  local opts = self:fn_command(prompt)
  if not opts then return end

  local writer = nil
  if opts.writer and Job.is_job(opts.writer) then
    writer = opts.writer
  elseif opts.writer then
    writer = Job:new(opts.writer)
  end

  self.job = Job:new {
    command = opts.command,
    args = opts.args,
    cwd = opts.cwd or self.cwd,

    maximum_results = self.maximum_results,

    writer = writer,

    enable_recording = false,

    on_stdout = on_output,
    on_stderr = on_output,

    on_exit = function()
      process_complete()
    end,
  }

  self.job:start()
end

local OneshotJobFinder = _callable_obj()

function OneshotJobFinder:new(opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")
  assert(not opts.static, "`static` should be used with finder.new_oneshot_job")

  local obj = setmetatable({
    fn_command = opts.fn_command,
    entry_maker = opts.entry_maker or make_entry.from_string,

    cwd = opts.cwd,
    writer = opts.writer,

    maximum_results = opts.maximum_results,

    _started = false,
  }, self)

  obj._find = coroutine.wrap(function(finder, _, process_result, process_complete)
    local num_execution = 1
    local num_results = 0

    local results = setmetatable({}, {
      __newindex = function(t, k, v)
        rawset(t, k, v)
        process_result(v)
      end
    })

    local job_opts = finder:fn_command(_)
    if not job_opts then
      error(debug.traceback("expected `job_opts` from fn_command"))
    end

    local writer = nil
    if job_opts.writer and Job.is_job(job_opts.writer) then
      writer = job_opts.writer
    elseif job_opts.writer then
      writer = Job:new(job_opts.writer)
    end

    local on_output = function(_, line)
      -- This will call the metamethod, process_result
      num_results = num_results + 1
      results[num_results] = finder.entry_maker(line)
    end

    local completed = false
    local job = Job:new {
      command = job_opts.command,
      args = job_opts.args,
      cwd = job_opts.cwd or finder.cwd,

      maximum_results = finder.maximum_results,

      writer = writer,

      enable_recording = false,

      on_stdout = on_output,
      on_stderr = on_output,

      on_exit = function()
        process_complete()
        completed = true
      end,
    }

    job:start()

    while true do
      finder, _, process_result, process_complete = coroutine.yield()
      num_execution = num_execution + 1

      local current_count = num_results
      for index = 1, current_count do
        process_result(results[index])
      end

      if completed then
        process_complete()
      end
    end
  end)

  return obj
end

function OneshotJobFinder:old_find(_, process_result, process_complete)
  local first_run = false

  if not self._started then
    first_run = true

    self._started = true

  end

  -- First time we get called, start on up that job.
  -- Every time after that, just use the results LUL
  if not first_run then
    return
  end
end



--[[ =============================================================
Static Finders

A static finder has results that never change.
They are passed in directly as a result.
-- ============================================================= ]]
local StaticFinder = _callable_obj()

function StaticFinder:new(opts)
  assert(opts, "Options are required. See documentation for usage")

  local input_results
  if vim.tbl_islist(opts) then
    input_results = opts
  else
    input_results = opts.results
  end

  local entry_maker = opts.entry_maker or make_entry.gen_from_string()

  assert(input_results)
  assert(input_results, "Results are required for static finder")
  assert(type(input_results) == 'table', "self.results must be a table")

  local results = {}
  for k, v in ipairs(input_results) do
    local entry = entry_maker(v)

    if entry then
      entry.index = k
      table.insert(results, entry)
    end
  end

  return setmetatable({ results = results }, self)
end

function StaticFinder:_find(_, process_result, process_complete)
  for _, v in ipairs(self.results) do
    process_result(v)
  end

  process_complete()
end


-- local


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

  return OneshotJobFinder:new {
    entry_maker = opts.entry_maker or make_entry.gen_from_string(),

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
