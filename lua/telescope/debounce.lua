-- Credit: https://gist.github.com/runiq/31aa5c4bf00f8e0843cd267880117201
--

local M = {}

---Validates args for `throttle()` and  `debounce()`.
local td_validate = function(fn, ms)
  vim.validate("fn", fn, "function")
  vim.validate("ms", ms, function(v)
    return type(v) == "number" and v > 0
  end, "number > 0")
end

--- Throttles a function on the leading edge. Automatically `schedule_wrap()`s.
---@param fn fun(...) Function to throttle
---@param ms integer Timeout in ms
---@return fun(...) wrapped_fn Throttled function
---@return uv.uv_timer_t timer Remember to call `timer.close()` at the end or you will leak memory!
function M.throttle_leading(fn, ms)
  td_validate(fn, ms)
  local timer = assert(vim.uv.new_timer())
  local running = false

  local function wrapped_fn(...)
    if not running then
      timer:start(ms, 0, function()
        running = false
      end)
      running = true
      pcall(vim.schedule_wrap(fn), select(1, ...))
    end
  end
  return wrapped_fn, timer
end

--- Throttles a function on the trailing edge. Automatically `schedule_wrap()`s.
---@param fn fun(...) Function to throttle
---@param ms integer Timeout in ms
---@param last? boolean Whether to use the arguments of the last call to `fn` within the timeframe.
--- Default: Use arguments of the first call.
---@return fun(...) wrapped_fn Throttled function
---@return uv.uv_timer_t timer Remember to call `timer.close()` at the end or you will leak memory!
function M.throttle_trailing(fn, ms, last)
  td_validate(fn, ms)
  local timer = assert(vim.uv.new_timer())
  local running = false

  local wrapped_fn
  if not last then
    function wrapped_fn(...)
      if not running then
        local argv = { ... }
        local argc = select("#", ...)

        timer:start(ms, 0, function()
          running = false
          pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
        end)
        running = true
      end
    end
  else
    local argv, argc
    function wrapped_fn(...)
      argv = { ... }
      argc = select("#", ...)

      if not running then
        timer:start(ms, 0, function()
          running = false
          pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
        end)
        running = true
      end
    end
  end
  return wrapped_fn, timer
end

--- Debounces a function on the leading edge. Automatically `schedule_wrap()`s.
---@param fn fun(...) Function to debounce
---@param ms integer Timeout in ms
---@return fun(...) wrapped_fn Debounced function
---@return uv.uv_timer_t timer Remember to call `timer.close()` at the end or you will leak memory!
function M.debounce_leading(fn, ms)
  td_validate(fn, ms)
  local timer = assert(vim.uv.new_timer())
  local running = false

  local function wrapped_fn(...)
    timer:start(ms, 0, function()
      running = false
    end)

    if not running then
      running = true
      pcall(vim.schedule_wrap(fn), select(1, ...))
    end
  end
  return wrapped_fn, timer
end

--- Debounces a function on the trailing edge. Automatically `schedule_wrap()`s.
---@param fn fun(...) Function to debounce
---@param ms integer Timeout in ms
---@param first? boolean Whether to use the arguments of the first call to `fn` within the timeframe.
--- Default: Use arguments of the last call.
---@return fun(...) wrapped_fn Debounced function
---@return uv.uv_timer_t timer Remember to call `timer.close()` at the end or you will leak memory!
function M.debounce_trailing(fn, ms, first)
  td_validate(fn, ms)
  local timer = assert(vim.uv.new_timer())
  local wrapped_fn

  if not first then
    function wrapped_fn(...)
      local argv = { ... }
      local argc = select("#", ...)

      timer:start(ms, 0, function()
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
    end
  else
    local argv, argc
    function wrapped_fn(...)
      argv = argv or { ... }
      argc = argc or select("#", ...)

      timer:start(ms, 0, function()
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
    end
  end
  return wrapped_fn, timer
end

return M
