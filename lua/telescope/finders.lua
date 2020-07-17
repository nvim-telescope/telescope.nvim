local a = vim.api

local finders = {}

---@class Finder
local Finder = {}

Finder.__index = Finder
Finder.__call = function(t, ... ) return t:_find(...) end

--- Create a new finder command
---
--@param fn_command function The function to call
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
    fn_command = opts.fn_command,
    responsive = opts.responsive,
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
function Finder:_find(prompt, process_result)
  if (self.state.job_id or 0) > 0 then
    vim.fn.jobstop(self.job_id)
  end

  -- TODO: How to just literally pass a list...
  -- TODO: How to configure what should happen here
  -- TODO: How to run this over and over?
  self.job_id = vim.fn.jobstart(self:fn_command(prompt), {
    stdout_buffered = true,

    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        process_result(line)
      end
    end
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
