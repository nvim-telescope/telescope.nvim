local ffi = require "ffi"
local native = require "telescope.ffi"

local EntryManager = {}
EntryManager.__index = EntryManager

function EntryManager:new(max_results, set_entry)
  return setmetatable({
    manager = ffi.gc(native.tele_manager_create(max_results), native.tele_manager_free),
    tbl = {},
    idx = 0,
    max_results = max_results,
    set_entry = vim.F.if_nil(set_entry, function() end),
  }, self)
end

function EntryManager:num_results()
  return tonumber(self.manager.list.len)
end

function EntryManager:worst_acceptable_score()
  return tonumber(self.manager.worst_acceptable_score)
end

local function __iter(self)
  local current_node = self.manager.list.head
  return function()
    local node = current_node
    if node == nil then
      return nil
    end

    current_node = current_node.next
    return self.tbl[node.item.idx], node.item.score
  end
end

function EntryManager:get_container(index)
  local k = 0
  local current_node = self.manager.list.head

  while true do
    local node = current_node
    if node == nil then
      return nil
    end
    current_node = current_node.next
    k = k + 1
    if k == index then
      return node.item
    end
  end
end

function EntryManager:get_entry(index)
  local node = self:get_container(index)
  if node then
    return self.tbl[node.idx]
  end
  return {}
end

function EntryManager:get_score(index)
  return self:get_container(index).score
end

function EntryManager:get_ordinal(index)
  return self:get_entry(index).ordinal
end

function EntryManager:find_entry(entry)
  local count = 0
  for o_entry in __iter(self) do
    count = count + 1

    if o_entry == entry then
      return count
    end
  end
end

function EntryManager:add_entry(picker, score, entry)
  score = score or 0

  self.idx = self.idx + 1
  self.tbl[self.idx] = entry
  local index = native.tele_manager_add(self.manager, self.idx, score)
  if index > 0 then
    self.set_entry(picker, index, entry, score, true)
  end
end

function EntryManager:iter()
  local iterator = __iter(self)
  return function()
    local val = iterator()
    return val
  end
end

function EntryManager:truncate() end

return EntryManager
