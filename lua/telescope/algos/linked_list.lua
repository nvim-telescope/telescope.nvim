
local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new()
  return setmetatable({ size = 0, head = false, tail = false }, self)
end

function LinkedList:_increment()
  self.size = self.size + 1
end

function LinkedList:append(item)
  self:_increment()

  local node = {}
  node.item = item

  if not self.head then
    self.head = node
  end

  local prev = nil
  if self.tail then
    self.tail.next = node
    node.prev = self.tail
  end

  self.tail = node
end

function LinkedList:insert(item)
  self:_increment()
end

-- Do you even do this in linked lists...?
-- function LinkedList:remove(item)
-- end

function LinkedList:iter()
  local current_node = self.head

  return function()
    local node = current_node
    if not node then
      return nil
    end

    current_node = current_node.next
    return node.item
  end
end

return LinkedList
