local entry_display = require('telescope.pickers.entry_display')
local LinkedList = require('telescope.algos.linked_list')
local log = require("telescope.log")

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

function EntryManager:new(max_results, set_entry, info)
  log.trace("Creating entry_manager...")

  info = info or {}
  info.looped = 0
  info.inserted = 0

  -- state contains list of
  --    {
  --        score = ...
  --        line = ...
  --        metadata ? ...
  --    }
  set_entry = set_entry or function() end

  return setmetatable({
    linked_states = LinkedList:new { track_at = max_results },
    info = info,
    max_results = max_results,
    set_entry = set_entry,
    worst_acceptable_score = math.huge,
  }, self)
end

function EntryManager:num_results()
  return self.linked_states.size
end

function EntryManager:get_container(index)
  local count = 0
  for val in self.linked_states:iter() do
    count = count + 1

    if count == index then
      return val
    end
  end

  -- return (linked_states[index] or {}).entry
  return nil
end

function EntryManager:get_entry(index)
  return self:get_container(index).entry
end

function EntryManager:get_ordinal(index)
  return self:get_entry(index).ordinal
end

function EntryManager:get_score(index)
  return self:get_container(index).score
end

function EntryManager:find_entry(entry)
  local count = 0
  for container in self.linked_states:iter() do
    count = count + 1

    if container.entry == entry then
      return count
    end
  end

  return nil
end

function EntryManager:_get_state()
  return self.linked_states
end

function EntryManager:should_save_result(index)
  return index <= self.max_results
end

function EntryManager:add_entry(picker, score, entry)
  score = score or 0

  local max_res = self.max_results

  local new_container = {
    score = score,
    entry = entry,
  }

  if score >= self.worst_acceptable_score then
    return self:append(new_container)
  end

  for index, container in self.linked_states:ipairs() do
    self.info.looped = self.info.looped + 1

    if container.score > score then
      return self:insert(picker, index, new_container)
    end

    -- Don't add results that are too bad.
    if index >= max_res then
      self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)
      return self:append(new_container)
    end
  end

  if self.linked_states.size >= max_res then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)
  end

  return self:insert(picker, self.linked_states.size + 1, new_container)
end

function EntryManager:append(container)
  -- assert(false)
  self.linked_states:append(container)
end

function EntryManager:insert(picker, index, container)
  assert(index)
  assert(container)

  -- Update the worst result if possible.
  if index >= self.max_results then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, container.score)
  end

  -- Simple case: Prepend beginning of list
  if index == 1 then
    self.linked_states:prepend(container)
    self.set_entry(picker, index, container.entry, container.score, true)
    print("Inserting:", vim.inspect(container))

  -- Simple case: Appending to end of list. No need to loop
  elseif index > self.linked_states.size then
    self.linked_states:append(container)

    if index <= self.max_results then
      self.set_entry(picker, index, container.entry, container.score)
    end

    return
  end

  for i, e, node in self.linked_states:ipairs() do
    self.info.looped = self.info.looped + 1

    if i == index - 1 then
      self.linked_states:place_after(node, container)
      self.set_entry(picker, index, container.entry, container.score, true)
    end

    if e.score >= self.worst_acceptable_score then
      error("Should not be able to reach this.")
      return
    end

    if i >= self.max_results then
      self.worst_acceptable_score = math.min(self.worst_acceptable_score, container.score)
      return
    end
  end
end


return EntryManager
