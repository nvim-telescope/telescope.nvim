local Job = require('plenary.job')

local log = require('telescope.log')

local finders = {}


-- TODO: We should make a few different "FinderGenerators":
--  SimpleListFinder(my_list)
--  FunctionFinder(my_func)
--  JobFinder(my_job_args)

---@class Finder
local Finder = {}

Finder.__index = Finder
Finder.__call = function(t, ... ) return t:_find(...) end

--- Create a new finder command
---
---@param opts table Keys:
--     fn_command function The function to call
function Finder:new(opts)
  opts = opts or {}

  -- TODO: Add config for:
  --        - cwd

  -- TODO:
  -- - `types`
  --    job
  --    pipe
  --        vim.loop.new_pipe (stdin / stdout). stdout => filter pipe
  --        rg huge_search | fzf --filter prompt_is > buffer. buffer could do stuff do w/ preview callback
  --    string
  --    list
  --    ...
  return setmetatable({
    results = opts.results,

    fn_command = opts.fn_command,
    static = opts.static,
    state = {},

    -- Maximum number of results to process.
    --  Particularly useful for live updating large queries.
    maximum_results = opts.maximum_results,
  }, Finder)
end

-- Probably should use the word apply here, since we're apply the callback passed to us by
--  the picker... But I'm not sure how we want to say that.

-- find_incremental
-- find_prompt
-- process_prompt
-- process_search
-- do_your_job
-- process_plz
function Finder:_find(prompt, process_result, process_complete)
  if self.results then
    assert(type(self.results) == 'table', "self.results must be a table")
    for _, v in ipairs(self.results) do
      process_result(v)
    end

    process_complete()
    return
  end

  if self.job and not self.job.is_shutdown then
    self.job:shutdown()
  end

  log.trace("Finding...")
  if self.static and self.done then
    log.trace("Using previous results")
    for _, v in ipairs(self._cached_lines) do
      process_result(v)
    end

    process_complete()
    return
  end

  if self.static then
    self._cached_lines = {}
  end

  self.done = false

  -- TODO: Should consider ways to allow "transformers" to be run here.
  --        So that a finder can choose to "transform" the text into something much more easily usable.
  local entries_processed = 0

  local on_output = function(_, line, _)
    if not line then
      return
    end

    if maximum_results then
      entries_processed = entries_processed + 1
      if entries_processed > maximum_results then
        log.info("Shutting down job early...")
        self.job:shutdown()
      end
    end

    if vim.trim(line) ~= "" then
      line = line:gsub("\n", "")

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

  self.job = Job:new {
    command = opts.command,
    args = opts.args,

    maximum_results = self.maximum_results,

    on_stdout = on_output,
    on_stderr = on_output,

    on_exit = function()
      self.done = true

      process_complete()
    end,
  }

  self.job:start()
end

--- Return a new Finder
--
--@return Finder
finders.new = function(...)
  return Finder:new(...)
end

finders.Finder = Finder

return finders
