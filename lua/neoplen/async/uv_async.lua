local a = require "neoplen.async.async"
local uv = vim.uv

local M = {}

local function add(name, argc)
  M[name] = a.wrap(uv[name], argc)
end

-- filesystem operations
add("fs_stat", 2)
add("fs_open", 4)
add("fs_close", 2)
add("fs_read", 4)
add("fs_write", 4)
add("fs_unlink", 2)
add("fs_realpath", 2)

return M
