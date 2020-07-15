--[[
A collection of builtin pipelines for telesceope.

Meant for both example and for easy startup.
--]]

local Finder = require('telescope.finder')
local pickers = require('telescope.pickers')

local builtin = {}

builtin.rg_vimgrep = setmetatable({}, {
  __call = function(t, ...)
    -- builtin.rg_vimgrep("--type lua function")
    print(t, ...)
  end
})

builtin.rg_vimgrep.finder = Finder:new {
  fn_command = function(prompt)
    return string.format('rg --vimgrep %s', prompt)
  end,

  responsive = false
}

builtin.rg_vimgrep.picker = pickers.new {
}


return builtin
