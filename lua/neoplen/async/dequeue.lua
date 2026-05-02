local Dequeue = {}
Dequeue.__index = Dequeue

---@class Deque
---A double ended queue
---
---@return Deque
function Dequeue.new()
  -- the indexes are created with an offset so that the indices are consequtive
  -- otherwise, when both pushleft and pushright are used, the indices will have a 1 length hole in the middle
  return setmetatable({ first = 0, last = -1 }, Dequeue)
end

---push to the left of the deque
---@param value any
function Dequeue:pushleft(value)
  local first = self.first - 1
  self.first = first
  self[first] = value
end

---push to the right of the deque
---@param value any
function Dequeue:pushright(value)
  local last = self.last + 1
  self.last = last
  self[last] = value
end

---pop from the left of the deque
---@return any
function Dequeue:popleft()
  local first = self.first
  if first > self.last then
    return nil
  end
  local value = self[first]
  self[first] = nil -- to allow garbage collection
  self.first = first + 1
  return value
end

---pops from the right of the deque
---@return any
function Dequeue:popright()
  local last = self.last
  if self.first > last then
    return nil
  end
  local value = self[last]
  self[last] = nil -- to allow garbage collection
  self.last = last - 1
  return value
end

---checks if the deque is empty
---@return boolean
function Dequeue:is_empty()
  return self:len() == 0
end

---returns the number of elements of the deque
---@return number
function Dequeue:len()
  return self.last - self.first + 1
end

---returns and iterator of the indices and values starting from the left
---@return function
function Dequeue:ipairs_left()
  local i = self.first

  return function()
    local res = self[i]
    local idx = i

    if res then
      i = i + 1

      return idx, res
    end
  end
end

---returns and iterator of the indices and values starting from the right
---@return function
function Dequeue:ipairs_right()
  local i = self.last

  return function()
    local res = self[i]
    local idx = i

    if res then
      i = i - 1 -- advance the iterator before we return

      return idx, res
    end
  end
end

---removes all values from the deque
---@return nil
function Dequeue:clear()
  for i, _ in self:ipairs_left() do
    self[i] = nil
  end
  self.first = 0
  self.last = -1
end

return Dequeue
