local log = require("telescope.log")

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
  local entry_state = {}

  set_entry = set_entry or function() end

  return setmetatable({
    set_entry = set_entry,
    max_results = max_results,
    worst_acceptable_score = math.huge,

    entry_state = entry_state,
    info = info,

    num_results = function()
      return #entry_state
    end,

    get_ordinal = function(self, index)
      return self:get_entry(index).ordinal
    end,

    get_entry = function(_, index)
      return (entry_state[index] or {}).entry
    end,

    get_score = function(_, index)
      return (entry_state[index] or {}).score
    end,

    find_entry = function(_, entry)
      if entry == nil then
        return nil
      end

      for k, v in ipairs(entry_state) do
        local existing_entry = v.entry

        -- FIXME: This has the problem of assuming that display will not be the same for two different entries.
        if existing_entry == entry then
          return k
        end
      end

      return nil
    end,

    _get_state = function()
      return entry_state
    end,
  }, self)
end

function EntryManager:should_save_result(index)
  return index <= self.max_results
end

function EntryManager:add_entry(picker, score, entry)
  score = score or 0

  if score >= self.worst_acceptable_score then
    return
  end

  for index, item in ipairs(self.entry_state) do
    self.info.looped = self.info.looped + 1

    if item.score > score then
      return self:insert(picker, index, {
        score = score,
        entry = entry,
      })
    end

    -- Don't add results that are too bad.
    if not self:should_save_result(index) then
      return
    end
  end

  return self:insert(picker, {
    score = score,
    entry = entry,
  })
end

function EntryManager:insert(picker, index, entry)
  if entry == nil then
    entry = index
    index = #self.entry_state + 1
  end

  -- To insert something, we place at the next available index (or specified index)
  -- and then shift all the corresponding items one place.
  local next_entry, last_score
  repeat
    self.info.inserted = self.info.inserted + 1
    next_entry = self.entry_state[index]

    self.set_entry(picker, index, entry.entry, entry.score)
    self.entry_state[index] = entry

    last_score = entry.score

    index = index + 1
    entry = next_entry
  until not next_entry or not self:should_save_result(index)

  if not self:should_save_result(index) then
    self.worst_acceptable_score = last_score
  end
end


return EntryManager
