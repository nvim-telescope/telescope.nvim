local ffi = require "ffi"

local library_path = (function()
  local dirname = string.sub(debug.getinfo(1).source, 2, #"/fzf_telescope.lua" * -1)
  if package.config:sub(1, 1) == "\\" then
    return dirname .. "../build/libtelescope.dll"
  else
    return dirname .. "../build/libtelescope.so"
  end
end)()
local native = ffi.load(library_path)

ffi.cdef [[
int new_linked_list();
]]

return native
