local MultiSelect = {}
MultiSelect.__index = MultiSelect

function MultiSelect:new()
  return setmetatable({
    _entries = {},
  }, MultiSelect)
end

function MultiSelect:get()
  local entries = self._entries
  local selections = vim.tbl_keys(entries)
  -- in the order they were selected
  table.sort(selections, function(left, right)
    return entries[left] < entries[right]
  end)
  return selections
end

function MultiSelect:is_selected(entry)
  return self._entries[entry]
end

local multi_select_count = 0
function MultiSelect:add(entry)
  multi_select_count = multi_select_count + 1
  self._entries[entry] = multi_select_count
end

function MultiSelect:drop(entry)
  self._entries[entry] = nil
end

function MultiSelect:toggle(entry)
  if self:is_selected(entry) then
    self:drop(entry)
  else
    self:add(entry)
  end
end

return MultiSelect
