local Job = require('plenary.job')

local make_entry = require('telescope.make_entry')
local log = require('telescope.log')

--[[ =============================================================

    JobFinder

Uses an external Job to get results. Processes results as they arrive.

For more information about how Jobs are implemented, checkout 'plenary.job'

-- ============================================================= ]]
local JobFinder = require('telescope.finders._shared').finder_obj()

--- Create a new finder command
---
---@param opts table Keys:
--     fn_command function The function to call
function JobFinder:new(opts)
  opts = opts or {}

  assert(not opts.results, "`results` should be used with finder.new_table")
  assert(not opts.static, "`static` should be used with finder.new_oneshot_job")

  local obj = setmetatable({
    entry_maker = opts.entry_maker or make_entry.gen_from_string(),
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

return JobFinder
