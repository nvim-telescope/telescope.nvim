local LinkedList = {}
LinkedList.__index = LinkedList

function LinkedList:new(opts)
  opts = opts or {}
  return setmetatable({
    size = 0,
    head = nil,
    tail = nil,

    track_at = opts.track_at,
    _tracked_node = nil,
    tracked = nil,
  }, self)
end

function LinkedList:_increment()
  self.size = self.size + 1
  return self.size
end

local function create_node(item)
  return { item = item }
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

  if self.track_at and final_size == self.track_at then
    self._tracked_node = node
    self.tracked = item
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

function LinkedList:place_after(index, node, item)
  assert(node, "place_after: node is nil")

  local new_node = create_node(item)
  local final_size = self:_increment()

  if self.tail == node then
    self.tail = new_node
  end

  new_node.prev = node
  new_node.next = node.next

  if node.next then
    node.next.prev = new_node
  end
  node.next = new_node

  if self.track_at then
    if index == self.track_at then
      self._tracked_node = new_node
    elseif index < self.track_at then
      if final_size == self.track_at then
        self._tracked_node = self.tail
      elseif final_size > self.track_at then
        self._tracked_node = self._tracked_node.prev
      else
        return
      end
    end
    self.tracked = self._tracked_node.item
  end
end

function LinkedList:place_before(index, node, item)
  assert(node, "place_before: node is nil")

  local new_node = create_node(item)
  local final_size = self:_increment()

  if self.head == node then
    self.head = new_node
  end

  new_node.next = node
  new_node.prev = node.prev

  if node.prev then
    node.prev.next = new_node
  end
  node.prev = new_node

  if self.track_at then
    if index == self.track_at - 1 then
      self._tracked_node = node
    elseif index < self.track_at then
      if final_size == self.track_at then
        self._tracked_node = self.tail
      elseif final_size > self.track_at then
        self._tracked_node = self._tracked_node.prev
      else
        return
      end
    end
    self.tracked = self._tracked_node.item
  end
end

function LinkedList:iter()
  local current = self.head
  return function()
    local node = current
    if not node then return nil end
    current = current.next
    return node.item
  end
end

function LinkedList:ipairs()
  local index = 0
  local current = self.head
  return function()
    local node = current
    if not node then return nil end
    index = index + 1
    current = current.next
    return index, node.item, node
  end
end

function LinkedList:truncate(max_results)
  if max_results >= self.size then return end

  local current

  if max_results < self.size - max_results then
    current = self.head
    for i = 1, max_results - 1 do
      current = current.next
    end
    self.size = max_results
  else
    current = self.tail
    while self.size > max_results do
      current = current.prev
      self.size = self.size - 1
    end
  end

  self.tail = current
  self.tail.next = nil

  if self.track_at and max_results < self.track_at then
    self.track_at = max_results
    self._tracked_node = current
    self.tracked = current.item
  end
end

return LinkedList
