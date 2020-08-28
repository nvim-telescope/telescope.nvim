local Entry = {}
Entry.__index = Entry

-- TODO: Can we / should we make it so that "display" and "ordinal" are just values, instead of functions.
--          It seems like that's what you'd want... No need to call the functions a million times.

-- Pass in a table, that contains some state
--  Table determines it's ordinal value
function Entry:new(line_or_obj)
  if type(line_or_obj) == "string" then
    return setmetatable({
      valid = line_or_obj ~= "",

      value = line_or_obj,
      ordinal = line_or_obj,
      display = line_or_obj,
    }, self)
  else
    return line_or_obj
  end
end

function Entry:__tostring()
  return "<" .. self.display .. ">"
end

return Entry
