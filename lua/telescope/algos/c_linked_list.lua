local ffi = require "ffi"
local native = require "telescope.ffi"

local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new(opts)
  opts = opts or {}

  return setmetatable({
    list = ffi.gc(native.fzf_list_create(opts.track_at), native.fzf_list_free),
    tbl = {},
    idx = 0,
  }, self)
end

function LinkedList:has_tracked()
  return self.list._tracked_node ~= nil
end

function LinkedList:tracked()
  return self.tbl[self.list._tracked_node.item]
end

function LinkedList:append(item)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.fzf_list_append(self.list, self.idx)
end

function LinkedList:prepend(item)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.fzf_list_prepend(self.list, self.idx)
end

function LinkedList:place_after(index, node, item)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.fzf_list_place_after(self.list, index, node, self.idx)
end

function LinkedList:place_before(index, node, item)
  self.idx = self.idx + 1
  self.tbl[self.idx] = item
  native.fzf_list_place_before(self.list, index, node, self.idx)
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
    return self.tbl[node.item]
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
    return index, self.tbl[node.item], node
  end
end

function LinkedList:truncate() end

return LinkedList
