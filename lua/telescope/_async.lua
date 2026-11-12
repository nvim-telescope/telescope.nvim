-- Coroutine helpers for pickers and finders. They wait only through this module, so the async runtime
-- is used in one place.
local async = require "neoplen.async"

local M = {}

--- Yield to the main loop; resumes from `vim.schedule`, where the API can be used.
M.yield = async.util.scheduler

--- Pass `list[1..n]` (which may have holes) to `process_result` until it returns true (the find is
--- stale), yielding to the main loop every 1000 entries.
---@param list table
---@param n integer
---@param process_result fun(entry: table?): boolean?
function M.process_list(list, n, process_result)
  for i = 1, n do
    if process_result(list[i]) then
      return
    end
    if i % 1000 == 0 then
      M.yield()
    end
  end
end

return M
