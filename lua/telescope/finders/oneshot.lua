local Job = require('plenary.job')

local log = require('telescope.log')
local shared = require('telescope.finders._shared')
local make_entry = require('telescope.make_entry')

local finder_obj = shared.finder_obj

local OneshotFinder = finder_obj()

function OneshotFinder:new(opts)
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

  local num_execution = 1
  local num_results = 0

  -- Default processor, completor. Set later.
  local result_processor = function(...) log.debug("Processed before set...?", ...) end
  local result_completor = function(...) log.debug("Complete before set...?", ... ) end

  local results = setmetatable({}, {
    __newindex = function(t, k, v)
      rawset(t, k, v)
      result_processor(v)
    end
  })

  local job_opts = obj:fn_command(prompt)
  if not job_opts then
    error(debug.trackeback("expected `job_opts` from fn_command"))
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
    results[num_results] = obj.entry_maker(line)
  end

  local completed = false
  local job = Job:new {
    command = job_opts.command,
    args = job_opts.args,
    cwd = job_opts.cwd or obj.cwd,

    maximum_results = obj.maximum_results,

    writer = writer,

    enable_recording = false,

    on_stdout = on_output,
    on_stderr = on_output,

    on_exit = function()
      result_completor()
      completed = true
    end,
  }

  obj._find = function(_, _, process_result, process_complete)
    result_processor = process_result
    result_completor = process_complete

    if vim.tbl_isempty(results) then
      job:start()
    end

    num_execution = num_execution + 1

    local current_count = num_results
    for index = 1, current_count do
      if process_result(results[index]) then
        print("WHOA DONE EARLY")
        return
      end
    end

    if completed then
      process_complete()
    end
  end

  return obj
end


return OneshotFinder
