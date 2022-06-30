-- TODO: I think it could be cool to set different functions depending on what configuration
-- you have (so for example, if you do not pass maxsize, we never check it)

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

    -- maxsize
    --      Use this to keep a limit on the nodes that we have.
    --      It's possible that we will insert MORE than this for some circumstances,
    --      so it's not a strict limit. But if something is appended after maxsize has
    --      been met, then we will just drop the item
    --
    --      We could fix that limitation by fixing all the other places, but my intuition
    --      is that it doesn't matter because the large percentage of additions are just appends
    --      (after the track at is passed)
    maxsize = opts.maxsize,
  }, self)
end

function LinkedList:_increment()
  self.size = self.size + 1
  return self.size
end

local create_node = function(item)
  return {
    item = item,
  }
end

function LinkedList:append(item)
  if self.maxsize and self.maxsize <= self.size then
    return
  end

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

-- [a, b, c]
--  b.prev = a
--  b.next = c
--
--  a.next = b
--  c.prev = c
--
-- insert d after b
-- [a, b, d, c]
--
--  b.next = d
--  b.prev = a
--
-- Place "item" after "node" (which is at index `index`)
function LinkedList:place_after(index, node, item)
  local new_node = create_node(item)

  assert(node.prev ~= node)
  assert(node.next ~= node)
  local final_size = self:_increment()

  -- Update tail to be the next node.
  if self.tail == node then
    self.tail = new_node
  end

  new_node.prev = node
  new_node.next = node.next

  node.next = new_node

  if new_node.prev then
    new_node.prev.next = new_node
  end

  if new_node.next then
    new_node.next.prev = new_node
  end

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
  local new_node = create_node(item)

  assert(node.prev ~= node)
  assert(node.next ~= node)
  local final_size = self:_increment()

  -- Update head to be the node we are inserting.
  if self.head == node then
    self.head = new_node
  end

  new_node.prev = node.prev
  new_node.next = node

  node.prev = new_node
  -- node.next = node.next

  if new_node.prev then
    new_node.prev.next = new_node
  end

  if new_node.next then
    new_node.next.prev = new_node
  end

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

function LinkedList:truncate(max_results)
  if max_results >= self.size then
    return
  end

  local current_node
  if max_results < self.size - max_results then
    local index = 1
    current_node = self.head
    while index < max_results do
      local node = current_node
      if not node.next then
        break
      end
      current_node = current_node.next
      index = index + 1
    end
    self.size = max_results
  else
    current_node = self.tail
    while self.size > max_results do
      if current_node.prev == nil then
        break
      end
      current_node = current_node.prev
      self.size = self.size - 1
    end
  end
  self.tail = current_node
  self.tail.next = nil
  if max_results < self.track_at then
    self.track_at = max_results
    self.tracked = current_node.item
    self._tracked_node = current_node
  end
end

return LinkedList
