local log = require("telescope.log")

--- Holds the results of a picker, best first.
---
--- The first `max_results` entries (the ones that can be shown) are kept sorted by score, with
--- binary search for the insert position. Entries that don't make it into those are kept, unsorted,
--- in a "rest": entries pushed out of the top go to its front, entries rejected right away to its
--- back. Everything is stored in plain arrays (no table per entry), with their lengths in fields
--- (`#t` is a binary search in LuaJIT unless the array part is full).
---@class EntryManager
local EntryManager = {}
EntryManager.__index = EntryManager

function EntryManager:new(max_results, set_entry)
  log.trace("Creating entry_manager...")

  return setmetatable({
    max_results = max_results,
    set_entry = set_entry or function() end,
    worst_acceptable_score = math.huge,
    -- the sorted top
    top_entries = {},
    top_scores = {},
    ntop = 0,
    -- the rest: `front` is stored reversed (its last element comes first), then `back`
    front_entries = {},
    front_scores = {},
    nfront = 0,
    back_entries = {},
    back_scores = {},
    nback = 0,
  }, self)
end

---@return integer
function EntryManager:num_results()
  return self.ntop + self.nfront + self.nback
end

--- Entry and score at `index` (1-based, best first).
function EntryManager:_get(index)
  local ntop = self.ntop
  if index <= ntop then
    return self.top_entries[index], self.top_scores[index]
  end
  index = index - ntop
  local nfront = self.nfront
  if index <= nfront then
    local k = nfront - index + 1
    return self.front_entries[k], self.front_scores[k]
  end
  index = index - nfront
  return self.back_entries[index], self.back_scores[index]
end

function EntryManager:get_entry(index)
  return (self:_get(index))
end

function EntryManager:get_score(index)
  local _, score = self:_get(index)
  return score
end

---@return integer? index
function EntryManager:find_entry(entry)
  local found
  local ntop, nfront, nback = self.ntop, self.nfront, self.nback
  local top_entries, front_entries, back_entries = self.top_entries, self.front_entries, self.back_entries
  for k = 1, ntop do
    if top_entries[k] == entry then
      found = k
      break
    end
  end
  if not found then
    for k = nfront, 1, -1 do
      if front_entries[k] == entry then
        found = ntop + nfront - k + 1
        break
      end
    end
  end
  if not found then
    for k = 1, nback do
      if back_entries[k] == entry then
        found = ntop + nfront + k
        break
      end
    end
  end
  return found
end

--- Append to the rest (not shown).
function EntryManager:_append(entry, score)
  local n = self.nback + 1
  self.nback = n
  self.back_entries[n] = entry
  self.back_scores[n] = score
end

--- Insert into the top at `index` and draw it. The last entry of a full top moves to the rest. Once
--- the top is full, its last score is the worst acceptable one.
function EntryManager:_insert(picker, index, entry, score)
  local max_res = self.max_results
  local top_entries, top_scores = self.top_entries, self.top_scores
  local ntop = self.ntop
  if ntop == max_res then
    local f = self.nfront + 1
    self.nfront = f
    self.front_entries[f] = top_entries[ntop]
    self.front_scores[f] = top_scores[ntop]
    ntop = ntop - 1
  end
  for k = ntop, index, -1 do
    top_entries[k + 1], top_scores[k + 1] = top_entries[k], top_scores[k]
  end
  top_entries[index], top_scores[index] = entry, score
  self.ntop = ntop + 1
  if ntop + 1 == max_res then
    self.worst_acceptable_score = top_scores[max_res]
  end
  self.set_entry(picker, index, entry, score, true)
end

function EntryManager:add_entry(picker, score, entry, prompt)
  score = score or 0

  -- Short circuit for bad scores: they never need to be displayed.
  if score >= self.worst_acceptable_score then
    return self:_append(entry, score)
  end

  local top_scores = self.top_scores
  local ntop = self.ntop

  -- Short circuit for the first entry.
  if self:num_results() == 0 then
    self.top_entries[1], top_scores[1] = entry, score
    self.ntop = 1
    if self.max_results == 1 then
      self.worst_acceptable_score = score
    end
    self.set_entry(picker, 1, entry, score)
    return
  end

  -- first index with a score >= `score` (`first_equal`) and > `score` (`first_worse`)
  local lo, hi = 1, ntop + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if top_scores[mid] >= score then
      hi = mid
    else
      lo = mid + 1
    end
  end
  local first_equal = lo
  hi = ntop + 1
  while lo < hi do
    local mid = math.floor((lo + hi) / 2)
    if top_scores[mid] > score then
      hi = mid
    else
      lo = mid + 1
    end
  end
  local first_worse = lo

  -- insert before the first worse score, or before the first equal one (< 1) the tiebreak
  -- prefers the new entry to
  local index = first_worse
  if score < 1 then
    local top_entries = self.top_entries
    for k = first_equal, first_worse - 1 do
      if picker.tiebreak(entry, top_entries[k], prompt) then
        index = k
        break
      end
    end
  end

  local max_res = self.max_results
  if index > max_res then
    -- don't add results that are too bad
    self:_append(entry, score)
    self.worst_acceptable_score = math.min(self.worst_acceptable_score, score)
    return
  end
  self:_insert(picker, index, entry, score)
end

--- Keep only the first `n` results.
function EntryManager:truncate(n)
  local entries, scores = {}, {}
  for k = 1, math.min(n, self:num_results()) do
    entries[k], scores[k] = self:_get(k)
  end
  local ntop = math.min(#entries, self.ntop)
  self.top_entries, self.top_scores, self.ntop = {}, {}, ntop
  self.front_entries, self.front_scores, self.nfront = {}, {}, 0
  self.back_entries, self.back_scores, self.nback = {}, {}, 0
  for k = 1, ntop do
    self.top_entries[k], self.top_scores[k] = entries[k], scores[k]
  end
  -- the rest keeps its order (as the back)
  for k = ntop + 1, #entries do
    self.nback = self.nback + 1
    self.back_entries[self.nback], self.back_scores[self.nback] = entries[k], scores[k]
  end
end

function EntryManager:iter()
  local index, n = 0, self:num_results()
  return function()
    index = index + 1
    if index <= n then
      return (self:_get(index))
    end
  end
end

return EntryManager
