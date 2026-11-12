-- Helpers for the picker's `vim.async` task: its main loop and the finds (calls of the finder) run
-- inside it.

local M = {}

--- Yield to the main loop; resumes from `vim.schedule`, where the API can be used.
function M.yield()
  vim.async.await(1, vim.schedule)
end

--- Pass `list[1..n]` (which may have holes) to `process_result`, yielding to the main loop every 1000
--- entries.
---@param list table
---@param n integer
---@param process_result fun(entry: table?)
function M.process_list(list, n, process_result)
  for i = 1, n do
    process_result(list[i])
    if i % 1000 == 0 then
      M.yield()
    end
  end
end

--- A wake-up signal: `send()` (from anywhere) resumes a `vim.async` task waiting in `wait()`; sends
--- while nobody waits are merged into one.
---@return fun() send
---@return async fun() wait
function M.signal()
  local pending, waiting = false, nil
  local function send()
    local cb = waiting
    if cb then
      waiting = nil
      cb()
    else
      pending = true
    end
  end
  local function wait()
    if pending then
      pending = false
      return
    end
    vim.async.await(function(cb)
      waiting = cb
    end)
  end
  return send, wait
end

return M
