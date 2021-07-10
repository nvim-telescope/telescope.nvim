local log = require("telescope.log")

local LinkedList = require('telescope.algos.linked_list')

--[[

OK, new idea.
We can do linked list here.
To convert at the end to quickfix, just run the list.
...

start node
end node

if past loop of must have scores,
  then we can just add to end node and shift end node to current node.
  etc.


  always inserts a row, because we clear everything before?

  can also optimize by keeping worst acceptable score around.

--]]

local EntryManager = {}
EntryManager.__index = EntryManager

--- Create a new EntryManager object
---@param max_results number: the number of results to keep sorted at the head of the linked list
---@param set_entry function: handler function for object using the EntryManager
---@param info table: (optional) table containing information to keep track of
---   @key looped number: number of existing entries checked when adding new entries
---   @key find_loop number: number of entries checked when trying to find an entry
---@return any
function EntryManager:new(max_results, set_entry, info)
  log.trace("Creating entry_manager...")

  info = info or {}
  info.looped = 0
  info.find_loop = 0

  -- state contains list of
  --    { entry, score }
  --    Stored directly in a table, accessed as [1], [2]
  set_entry = set_entry or function() end

  return setmetatable({
    linked_states = LinkedList:new { track_at = max_results },
    info = info,
    max_results = max_results,
    set_entry = set_entry,
    worst_acceptable_score = math.huge,
  }, self)
end

--- Get the number of entries in the manager
---@return number
function EntryManager:num_results()
  return self.linked_states.size
end

--- Get the container in the EntryManager corresponding to `index`
---@param index number
---@return table: contains the entry at index 1 and the score at index 2
function EntryManager:get_container(index)
  local count = 0
  for val in self.linked_states:iter() do
    count = count + 1

    if count == index then
      return val
    end
  end

  return {}
end

--- Get the entry in the EntryManager corresponding to `index`
---@param index number
---@return table: table with information about the given entry
function EntryManager:get_entry(index)
  return self:get_container(index)[1]
end

--- Get the score in the EntryManager corresponding to `index`
---@param index number
---@return number
function EntryManager:get_score(index)
  return self:get_container(index)[2]
end

--- Get the `ordinal` (text to be filtered on) corresponding to `index`
---@param index number
---@return string
function EntryManager:get_ordinal(index)
  return self:get_entry(index).ordinal
end

--- Get the index of the given entry in the EntryManager
---@param entry table: table with information about the given entry
---@return number|nil: the index of the entry if is present, nil otherwise
function EntryManager:find_entry(entry)
  local info = self.info

  local count = 0
  for container in self.linked_states:iter() do
    count = count + 1

    if container[1] == entry then
      info.find_loop = info.find_loop + count

      return count
    end
  end

  info.find_loop = info.find_loop + count
  return nil
end

--- Update the `worst_acceptable_score` based on the score of the tracked entry
function EntryManager:_update_score_from_tracked()
  local linked = self.linked_states

  if linked.tracked then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, linked.tracked[2])
  end
end

--- Insert the `new_container` before the `linked_node` which is in position `index` in the
--- associated linked list of the EntryManager and update tracked information accordingly
---@note: this is basically a wrapper for `linked_list.place_before`
---@param picker table: the associated picker for the entry manager
---@param index number: the position to place the entry
---@param linked_node table: the node currently in the `index` position of the linked list
---@param new_container table: the container to be inserted into the linked list
function EntryManager:_insert_container_before(picker, index, linked_node, new_container)
  self.linked_states:place_before(index, linked_node, new_container)
  self.set_entry(picker, index, new_container[1], new_container[2], true)

  self:_update_score_from_tracked()
end

--- Insert the `new_container` after the `linked_node` which is in position `index` in the
--- associated linked list of the EntryManager and update tracked information accordingly
---@note: this is basically a wrapper for `linked_list.place_after`
---@param picker table: the associated picker for the entry manager
---@param index number: the position to place the entry
---@param linked_node table: the node currently in the `index` position of the linked list
---@param new_container table: the container to be inserted into the linked list
function EntryManager:_insert_container_after(picker, index, linked_node, new_container)
  self.linked_states:place_after(index, linked_node, new_container)
  self.set_entry(picker, index, new_container[1], new_container[2], true)

  self:_update_score_from_tracked()
end

--- Append the `new_container` to the end of the linked list associated to the EntryManager.
--- If `should_update` is `true`, then the tracked information is updated.
---@param picker table: the associated picker for the entry manager
---@param new_container table: the container to be appended to the linked list
---@param should_update boolean
function EntryManager:_append_container(picker, new_container, should_update)
  self.linked_states:append(new_container)
  self.worst_acceptable_score = math.min(self.worst_acceptable_score, new_container[2])

  if should_update then
    self.set_entry(picker, self.linked_states.size, new_container[1], new_container[2])
  end
end

--- Adds `new_container` to the associated linked list.
--- If `score` is less than `worst_acceptable_score` then
--- `new_container` is placed in the position that puts it
--- in order. Otherwise, `new_container` is simply appended
--- to the linked list.
--- The `worst_acceptable_score` and `info.maxed` are updated
--- when needed.
---@param picker table: the associated picker for the entry manager
---@param score number: the score of the entry to be added
---@param entry table: the entry to be added to the manager
---@return nil
function EntryManager:add_entry(picker, score, entry)
  score = score or 0

  local max_res = self.max_results
  local worst_score = self.worst_acceptable_score
  local size = self.linked_states.size

  local info = self.info
  info.maxed = info.maxed or 0

  local new_container = { entry, score, }

  -- Short circuit for bad scores -- they never need to be displayed.
  --    Just save them and we'll deal with them later.
  if score >= worst_score then
    return self.linked_states:append(new_container)
  end

  -- Short circuit for first entry.
  if size == 0 then
    self.linked_states:prepend(new_container)
    self.set_entry(picker, 1, entry, score)
    return
  end

  for index, container, node in self.linked_states:ipairs() do
    info.looped = info.looped + 1

    if container[2] > score then
      -- print("Inserting: ", picker, index, node, new_container)
      return self:_insert_container_before(picker, index, node, new_container)
    end

    -- Don't add results that are too bad.
    if index >= max_res then
      info.maxed = info.maxed + 1
      return self:_append_container(picker, new_container, false)
    end
  end

  if self.linked_states.size >= max_res then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)
  end

  return self:_insert_container_after(picker, size + 1, self.linked_states.tail, new_container)
end

--- Get an iterator for the entries in the associated linked list
function EntryManager:iter()
  return coroutine.wrap(function()
    for val in self.linked_states:iter() do
      coroutine.yield(val[1])
    end
  end)
end

return EntryManager
