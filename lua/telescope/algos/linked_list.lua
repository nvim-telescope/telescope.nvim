
local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new(opts)
  opts = opts or {}
  local track_at = opts.track_at

  return setmetatable({
    size = 0,
    head = false,
    tail = false,

    -- track_at: Track at can track a particular node
    --              Use to keep a node tracked at a particular index
    --              This greatly decreases looping for checking values at this location.
    track_at = track_at,
    _tracked_node = nil,
    tracked = nil,
  }, self)
end

function LinkedList:_increment()
  self.size = self.size + 1
  return self.size
end

local create_node = function(item)
  return {
    item = item
  }
end

function LinkedList:append(item)
  local final_size = self:_increment()

  local node = create_node(item)

  if not self.head then
    self.head = node
  end

  if self.tail then
    self.tail.next = node
    node.prev = self.tail
  end

  self.tail = node

  if self.track_at then
    if final_size == self.track_at then
      self.tracked = item
      self._tracked_node = node
    end
  end
end

function LinkedList:prepend(item)
  local final_size = self:_increment()
  local node = create_node(item)

  if not self.tail then
    self.tail = node
  end

  if self.head then
    self.head.prev = node
    node.next = self.head
  end

  self.head = node

  if self.track_at then
    if final_size == self.track_at then
      self._tracked_node = self.tail
    elseif final_size > self.track_at then
      self._tracked_node = self._tracked_node.prev
    else
        return
    end

    self.tracked = self._tracked_node.item
  end
end

function LinkedList:place_after(node, item)
  local new_node = create_node(item)

  assert(node.prev ~= node)
  assert(node.next ~= node)
  self:_increment()

  if self.tail == node then
    self.tail = new_node
  end

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
