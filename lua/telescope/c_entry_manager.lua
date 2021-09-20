local log = require "telescope.log"

local LinkedList = require "telescope.algos.c_linked_list"

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
  log.trace "Creating entry_manager..."

  info = info or {}
  info.looped = 0
  info.inserted = 0
  info.find_loop = 0

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
  return self.linked_states:size()
end

function EntryManager:get_container(index)
  for k, entry, score in self.linked_states:ipairs() do
    if k == index then
      return entry, score
    end
  end

  return {}
end

function EntryManager:get_entry(index)
  local entry = self:get_container(index)
  return entry
end

function EntryManager:get_score(index)
  local _, score = self:get_container(index)
  return score
end

function EntryManager:get_ordinal(index)
  return self:get_entry(index).ordinal
end

function EntryManager:find_entry(entry)
  local info = self.info

  local count = 0
  for o_entry in self.linked_states:iter() do
    count = count + 1

    if o_entry == entry then
      info.find_loop = info.find_loop + count

      return count
    end
  end

  info.find_loop = info.find_loop + count
  return nil
end

function EntryManager:_update_score_from_tracked()
  if self.linked_states:has_tracked() then
    local _, tracked_score = self.linked_states:tracked()
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, tracked_score)
  end
end

function EntryManager:_insert_container_before(picker, index, linked_node, entry, score)
  self.linked_states:place_before(index, linked_node, entry, score)
  self.set_entry(picker, index, entry, score, true)

  self:_update_score_from_tracked()
end

function EntryManager:_insert_container_after(picker, index, linked_node, entry, score)
  self.linked_states:place_after(index, linked_node, entry, score)
  self.set_entry(picker, index, entry, score, true)

  self:_update_score_from_tracked()
end

function EntryManager:_append_container(picker, entry, score, should_update)
  self.linked_states:append(entry, score)
  self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)

  if should_update then
    self.set_entry(picker, self.linked_states:size(), entry, score)
  end
end

function EntryManager:add_entry(picker, score, entry)
  score = score or 0

  local max_res = self.max_results
  local worst_score = self.worst_acceptable_score
  local size = self.linked_states:size()

  local info = self.info
  info.maxed = info.maxed or 0

  -- Short circuit for bad scores -- they never need to be displayed.
  --    Just save them and we'll deal with them later.
  if score >= worst_score then
    return self.linked_states:append(entry, score)
  end

  -- Short circuit for first entry.
  if size == 0 then
    self.linked_states:prepend(entry, score)
    self.set_entry(picker, 1, entry, score)
    return
  end

  for index, o_entry, o_score, node in self.linked_states:ipairs() do
    info.looped = info.looped + 1

    if o_score > score then
      return self:_insert_container_before(picker, index, node, entry, score)
    end

    if score < 1 and o_score == score and #entry.ordinal < #o_entry.ordinal then
      return self:_insert_container_before(picker, index, node, entry, score)
    end

    -- Don't add results that are too bad.
    if index >= max_res then
      info.maxed = info.maxed + 1
      return self:_append_container(picker, entry, score, false)
    end
  end

  if self.linked_states:size() >= max_res then
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)
  end

  return self:_insert_container_after(picker, size + 1, self.linked_states.list.tail, entry, score)
end

function EntryManager:iter()
  local iterator = self.linked_states:iter()
  return function()
    local val = iterator()
    return val
  end
end

return EntryManager
