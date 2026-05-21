---@brief [[
--- NOTE: This API is still under construction.
---         It may change in the future :)
---@brief ]]

local lookups = {
  util = "neoplen.async.util",
  control = "neoplen.async.control",
  uv = "neoplen.async.uv_async",
}

local M = setmetatable(require "neoplen.async.async", {
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

return M
