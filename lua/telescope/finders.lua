local Job = require('plenary.job')

local make_entry = require('telescope.make_entry')
local log = require('telescope.log')

local finders = {}

-- TODO: We should make a few different "FinderGenerators":
--  SimpleListFinder(my_list)
--  FunctionFinder(my_func)
--  JobFinder(my_job_args)

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

  assert(not opts.results, "`results` should be used with finder.new_table")
  -- TODO:
  -- - `types`
  --    job
  --    pipe
  --        vim.loop.new_pipe (stdin / stdout). stdout => filter pipe
  --        rg huge_search | fzf --filter prompt_is > buffer. buffer could do stuff do w/ preview callback

  local obj = setmetatable({
    entry_maker = opts.entry_maker or make_entry.from_string,
    fn_command = opts.fn_command,
    static = opts.static,
    state = {},

    cwd = opts.cwd,
    writer = opts.writer,

    -- Maximum number of results to process.
    --  Particularly useful for live updating large queries.
    maximum_results = opts.maximum_results,
  }, self)

  return obj
end

function JobFinder:_find(prompt, process_result, process_complete)
  START = vim.loop.hrtime()
  PERF()
  PERF('starting...')

  if self.job and not self.job.is_shutdown then
    PERF('...had to shutdown')
    self.job:shutdown()
  end

  log.trace("Finding...")
  if self.static and self.done then
    log.trace("Using previous results")
    for _, v in ipairs(self._cached_lines) do
      process_result(v)
    end

    process_complete()
    PERF('Num Lines: ', self._cached_lines)
    PERF('...finished static')

    COMPLETED = true
    return
  end

  self.done = false
  self._cached_lines = {}

  local on_output = function(_, line, _)
    if not line then
      return
    end

    if line ~= "" then
      if self.entry_maker then
        line = self.entry_maker(line)
      end

      process_result(line)

      if self.static then
        table.insert(self._cached_lines, line)
      end
    end
  end

  -- TODO: How to just literally pass a list...
  -- TODO: How to configure what should happen here
  -- TODO: How to run this over and over?
  local opts = self:fn_command(prompt)
  if not opts then return end

  local writer = nil
  if opts.writer and Job.is_job(opts.writer) then
    print("WOW A JOB")
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
      self.done = true

      process_complete()

      PERF('done')
    end,
  }

  self.job:start()
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
  for _, v in ipairs(input_results) do
    table.insert(results, entry_maker(v))
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

  return JobFinder:new {
    static = true,

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
