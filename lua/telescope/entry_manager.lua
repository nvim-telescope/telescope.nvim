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
  local linked_states = {}

  set_entry = set_entry or function() end

  return setmetatable({
    linked_states = LinkedList:new(),
    info = info,
    max_results = max_results,
    set_entry = set_entry,
    worst_acceptable_score = math.huge,
  }, self)
end

function EntryManager:num_results()
  return self.linked_states.size
end

function EntryManager:get_entry(index)
  local count = 0
  for val in self.linked_states:iter() do
    count = count + 1

    if count == index then
      return val.entry
    end
  end

  -- return (linked_states[index] or {}).entry
  return nil
end

function EntryManager:get_ordinal(index)
  return self:get_entry(index).ordinal
end

function EntryManager:get_score(index)
  return self:get_entry(index).score
end

function EntryManager:find_entry(entry)
  local count = 0
  for val in self.linked_states:iter() do
    count = count + 1

    if val.entry == entry then
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

  local new_item = {
    score = score,
    entry = entry,
  }

  if score >= self.worst_acceptable_score then
    self.linked_states:append(new_item)
    return
  end

  for index, item in self.linked_states:ipairs() do
    self.info.looped = self.info.looped + 1

    if item.score > score then
      return self:insert(picker, index, new_item)
    end

    -- Don't add results that are too bad.
    if not self:should_save_result(index) then
      return
    end
  end

  return self:insert(picker, self.linked_states.size + 1, {
    score = score,
    entry = entry,
  })
end

function EntryManager:insert(picker, index, entry)
  assert(index)
  assert(entry)

  -- This is the append case.
  -- Just add it at the end
  if index > self.linked_states.size then
    self.linked_states:append(entry)

    if index <= self.max_results then
      self.set_entry(picker, index, entry.entry, entry.score)
    end

    return
  end

  -- TODO: Add `shift_entry` which just pushes things down one line
  for i, e, node in self.linked_states:ipairs() do
    if i == index then
      self.linked_states:place_after(node, entry)
      self.set_entry(picker, index, entry.entry, entry.score, true)
      return
    elseif i > index then
      assert(false, "Cannot get here")
    end

    if i > self.max_results then
      print("Quit because of max results")
      return
    end
  end

  -- To insert something, we place at the next available index
  -- (or specified index) and then shift all the corresponding
  -- items one place.
  -- local next_entry, last_score
  -- repeat
  --   self.info.inserted = self.info.inserted + 1
  --   next_entry = self.linked_states[index]

  --   self.set_entry(picker, index, entry.entry, entry.score)
  --   self.linked_states[index] = entry

  --   last_score = entry.score

  --   index = index + 1
  --   entry = next_entry
  -- until not next_entry or not self:should_save_result(index)

  -- if not self:should_save_result(index) then
  --   self.worst_acceptable_score = last_score
  -- end
end


return EntryManager
