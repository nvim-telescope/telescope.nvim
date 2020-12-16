
local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new()
  return setmetatable({ size = 0, head = false, tail = false }, self)
end

function LinkedList:_increment()
  self.size = self.size + 1
end

local create_node = function(item)
  return {
    item = item
  }
end

function LinkedList:append(item)
  self:_increment()
  local node = create_node(item)

  if not self.head then
    self.head = node
  end

  if self.tail then
    self.tail.next = node
    node.prev = self.tail
  end

  self.tail = node
end

function LinkedList:prepend(item)
  self:_increment()
  local node = create_node(item)

  if not self.tail then
    self.tail = node
  end

  if self.head then
    self.head.prev = node
    node.next = self.head
  end

  self.head = node
end

function LinkedList:place_after(node, item)
  local new_node = create_node(item)

  assert(node.prev ~= node)
  assert(node.next ~= node)
  self:_increment()

  new_node.prev = node.prev
  new_node.next = node

  node.prev = new_node
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

function LinkedList:ipairs()
  local index = 0
  local current_node = self.head

  return function()
    local node = current_node
    if not node then
      return nil
    end

    current_node = current_node.next
    index = index + 1
    return index, node.item, node
  end
end

return LinkedList
