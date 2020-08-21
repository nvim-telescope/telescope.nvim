local a = vim.api
local log = require('telescope.log')

local finders = {}

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
    job_id = -1,
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

  if (self.state.job_id or 0) > 0 then
    vim.fn.jobstop(self.job_id)
  end

  log.info("Finding...")
  if self.static and self.done then
    log.info("Using previous results")
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

  -- TODO: How to just literally pass a list...
  -- TODO: How to configure what should happen here
  -- TODO: How to run this over and over?
  self.job_id = vim.fn.jobstart(self:fn_command(prompt), {
    stdout_buffered = true,

    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        if vim.trim(line) ~= "" then
          process_result(line)

          if self.static then
            table.insert(self._cached_lines, line)
          end
        end
      end
    end,

    on_exit = function()
      self.done = true

      process_complete()
    end,
  })
end

--- Return a new Finder
--
--@return Finder
finders.new = function(...)
  return Finder:new(...)
end

finders.Finder = Finder

return finders
