local selector = {}

local state = {
  None = 0,
  Some = 1,
}

---@class Selection
---@field state number: The current state (None or Some)
---@field row number: The selected row
---@field entry table: The selected entry
local Selection = {}
Selection.__index = Selection

function Selection:none()
  return setmetatable({ state = state.None }, Selection)
end

function Selection:some(row, entry)
  return setmetatable({ state = state.Some, row = row, entry = entry }, Selection)
end

--- Reset the selection of the picker
---@param picker Picker
selector.reset = function(picker)
  picker._selection = Selection:some()
end

return selector
