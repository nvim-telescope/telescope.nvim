local a = require "neoplen.async.async"
local control = require "neoplen.async.control"
local channel = control.channel

local M = {}

local defer_swapped = function(timeout, callback)
  vim.defer_fn(callback, timeout)
end

---Sleep for milliseconds
---@param ms number
M.sleep = a.wrap(defer_swapped, 2)

---This will COMPLETELY block neovim
---please just use a.run unless you have a very special usecase
---for example, in plenary test_harness you must use this
---@param async_function Future
---@param timeout number: Stop blocking if the timeout was surpassed. Default 2000.
M.block_on = function(async_function, timeout)
  async_function = M.protected(async_function)

  local stat
  local ret = {}

  a.run(async_function, function(stat_, ...)
    stat = stat_
    ret = { ... }
  end)

  vim.wait(timeout or 2000, function()
    return stat ~= nil
  end, 20, false)

  if stat == false then
    error(string.format("Blocking on future timed out or was interrupted.\n%s", unpack(ret)))
  end

  return unpack(ret)
end

---@see M.block_on
---@param async_function Future
---@param timeout number
M.will_block = function(async_function, timeout)
  return function()
    M.block_on(async_function, timeout)
  end
end

M.join = function(async_fns)
  local len = #async_fns
  local results = {}
  if len == 0 then
    return results
  end

  local done = 0

  local tx, rx = channel.oneshot()

  for i, async_fn in ipairs(async_fns) do
    assert(type(async_fn) == "function", "type error :: future must be function")

    local cb = function(...)
      results[i] = { ... }
      done = done + 1
      if done == len then
        tx()
      end
    end

    a.run(async_fn, cb)
  end

  rx()

  return results
end

---Returns a result from the future that finishes at the first
---@param async_functions table: The futures that you want to select
---@return ...
M.run_first = a.wrap(function(async_functions, step)
  local ran = false

  for _, async_function in ipairs(async_functions) do
    assert(type(async_function) == "function", "type error :: future must be function")

    local callback = function(...)
      if not ran then
        ran = true
        step(...)
      end
    end

    async_function(callback)
  end
end, 2)

---Returns a result from the functions that finishes at the first
---@param funcs table: The async functions that you want to select
---@return ...
M.race = function(funcs)
  local async_functions = vim.tbl_map(function(func)
    return function(callback)
      a.run(func, callback)
    end
  end, funcs)
  return M.run_first(async_functions)
end

M.run_all = function(async_fns, callback)
  a.run(function()
    M.join(async_fns)
  end, callback)
end

function M.apcall(async_fn, ...)
  local nargs = a.get_leaf_function_argc(async_fn)
  if nargs then
    local tx, rx = channel.oneshot()
    local stat, ret = pcall(async_fn, require("neoplen.async.vararg").rotate(nargs, tx, ...))
    if not stat then
      return stat, ret
    else
      return stat, rx()
    end
  else
    return pcall(async_fn, ...)
  end
end

function M.protected(async_fn)
  return function()
    return M.apcall(async_fn)
  end
end

---An async function that when called will yield to the neovim scheduler to be able to call the api.
M.scheduler = a.wrap(vim.schedule, 1)

return M
