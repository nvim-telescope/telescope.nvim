local ffi = require "ffi"
local native = require "telescope.ffi"

local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new(opts)
  opts = opts or {}

  return setmetatable({
    list = ffi.gc(native.tele_list_create(opts.track_at), native.tele_list_free),
    tbl = {},
    idx = 0,
  }, self)
end

function LinkedList:has_tracked()
  return self.list._tracked_node ~= nil
end

function LinkedList:tracked()
  return self.tbl[self.list._tracked_node.item.idx], self.list._tracked_node.item.score
end

function LinkedList:append(item, score)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.tele_list_append(self.list, self.idx, score)
end

function LinkedList:prepend(item, score)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.tele_list_prepend(self.list, self.idx, score)
end

function LinkedList:place_after(index, node, item, score)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.tele_list_place_after(self.list, index, node, self.idx, score)
end

function LinkedList:place_before(index, node, item, score)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.tele_list_place_before(self.list, index, node, self.idx, score)
end

function LinkedList:size()
  return tonumber(self.list.len)
end

function LinkedList:iter()
  local current_node = self.list.head
  return function()
    local node = current_node
    if node == nil then
      return nil
    end

    current_node = current_node.next
    return self.tbl[node.item.idx], node.item.score
  end
end

function LinkedList:ipairs()
  local index = 0
  local current_node = self.list.head

  return function()
    local node = current_node
    if node == nil then
      return nil
    end

    current_node = current_node.next
    index = index + 1
    return index, self.tbl[node.item.idx], node.item.score, node
  end
end

function LinkedList:truncate() end

return LinkedList
