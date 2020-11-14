
local shared = {}

shared.finder_obj = function()
  local obj = {}

  obj.__index = obj
  obj.__call = function(t, ...) return t:_find(...) end

  return obj
end

return shared
