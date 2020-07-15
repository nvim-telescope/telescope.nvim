local previewers = {}

local Previewer = {}
Previewer.__index = Previewer

function Previewer:new(fn)
  return setmetatable({
    fn = fn,
  }, Previewer)
end

previewers.new = function(...)
  return Previewer:new(...)
end

return previewers
