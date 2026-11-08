---@brief [[
--- NOTE: This API is still under construction.
---         It may change in the future :)
---@brief ]]

local lookups = {
  uv = "neoplen.async.uv_async",
  util = "neoplen.async.util",
  lsp = "neoplen.async.lsp",
  api = "neoplen.async.api",
  tests = "neoplen.async.tests",
  control = "neoplen.async.control",
}

local exports = setmetatable(require "neoplen.async.async", {
  __index = function(t, k)
    local require_path = lookups[k]
    if not require_path then
      return
    end

    local mod = require(require_path)
    t[k] = mod

    return mod
  end,
})

exports.tests.add_globals = function()
  a = exports

  -- must prefix with a or stack overflow, plenary.test harness already added it
  a.describe = exports.tests.describe
  -- must prefix with a or stack overflow
  a.it = exports.tests.it
  a.pending = exports.tests.pending
  a.before_each = exports.tests.before_each
  a.after_each = exports.tests.after_each
end

exports.tests.add_to_env = function()
  local env = getfenv(2)

  env.a = exports

  -- must prefix with a or stack overflow, plenary.test harness already added it
  env.a.describe = exports.tests.describe
  -- must prefix with a or stack overflow
  env.a.it = exports.tests.it
  env.a.pending = exports.tests.pending
  env.a.before_each = exports.tests.before_each
  env.a.after_each = exports.tests.after_each

  setfenv(2, env)
end

return exports
