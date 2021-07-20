
local LinkedList = {}
LinkedList.__index = LinkedList

---@brief [[
--- A linked list consists of a collection of "nodes", which contain information about:
--- - the identity of their predecessor, under the `prev` key
--- - the identity of their successor, under the `next` key
--- - some stored information associated to themselves, under the `item` key
---
--- So locally at each node the picture of the linked list looks like:
--- <pre>
---      ┌──────────┐ B.prev ┌──────────┐ C.prev ┌──────────┐
--- ◄────│    A     │◄───────│    B     │◄───────│    C     │◄────
---  ... │ ┌──────┐ │        │ ┌──────┐ │        │ ┌──────┐ │ ...
--- ────►│ │A.item│ │───────►│ │B.item│ │───────►│ │C.item│ │────►
---      │ └──────┘ │ A.next │ └──────┘ │ B.next │ └──────┘ │
---      └──────────┘        └──────────┘        └──────────┘
--- </pre>
---
--- There are two special nodes in the linked list, the `head` and the `tail`.
--- The `head` is a node which has no predecessor, so `head.prev=nil`.
--- The `tail` is a node which has no successor, so `head.next=nil`.
---
--- The number of nodes in the linked list is stored under the `size` key.
---
--- This implementation also allows a specific index to be kept track of.
--- The index is called `track_at`, and the node at that index is called `_tracked_node`.
--- The information stored in the tracked node i.e. `_tracked_node.item` is stored under the
--- `tracked` key.
---
--- The global picture of a linked list looks like:
--- <pre>
--- ┌────────┐           ┌───────────────┐           ┌────────┐
--- │ `head` │◄───   ◄───│ _tracked_node │◄───   ◄───│ `tail` │
--- │ ┌────┐ │    ...    │   ┌───────┐   │    ...    │ ┌────┐ │
--- │ │item│ │───►   ───►│   │tracked│   │───►   ───►│ │item│ │
--- │ └────┘ │           │   └───────┘   │           │ └────┘ │
--- └────────┘           └───────────────┘           └────────┘
--- </pre>
---@brief ]]


--- Create a new linked list
---@param opts table
---   @key track_at number: the index of the node to track
---@return any
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

--- Increment the size of the linked list and return the new size
---@return number
function LinkedList:_increment()
  self.size = self.size + 1
  return self.size
end

--- Helper function that wraps `item` in a table at key `item`.
---@param item any
---@return table
local create_node = function(item)
  return {
    item = item
  }
end

--- Add a node with information `item` at the end of the linked list.
--- The tracked information is updated as necessary.
---@note: the newly created node will be the `tail` of the linked list.
---@param item any
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

--- Add a node with information `item` at the beginning of the linked list.
--- The tracked information is updated as necessary.
---@note: the newly created node will be the `head` of the linked list.
---@param item any
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
--  c.prev = d
--

--- Place "item" after "node" (which is at index `index`)
---@param index number
---@param node table
---@param item any
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

-- [a, b, c]
--  b.prev = a
--  b.next = c
--
--  a.next = b
--  c.prev = c
--
-- insert d before b
-- [a, d, b, c]
--
--  a.next = d
--  b.prev = d
--

--- Place "item" before "node" (which is at index `index`)
---@param index number
---@param node table
---@param item any
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

--- Convert the linked list to an iterator function for the node `item`s
---@return function
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

--- Convert the linked list to an iterator of `index`, `item`, `node` triples
---@note: can also be used as an iterator of `index`, `item` pairs
---@return function
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
