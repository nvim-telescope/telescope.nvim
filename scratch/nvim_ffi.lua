local ffi = require("ffi")
-- ffi.load("/home/tj/build/neovim/build/include/eval/funcs.h.generated.h")

ffi.cdef [[
typedef unsigned char char_u;
char_u *shorten_dir(char_u *str);
]]

local text = "scratch/file.lua"
local c_str = ffi.new("char[?]", #text)
ffi.copy(c_str, text)

print(vim.inspect(ffi.string(ffi.C.shorten_dir(c_str))))


