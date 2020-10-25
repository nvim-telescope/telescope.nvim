local log = require('telescope.log')

local PromptCache = {}

function getFirstByteDiffIdx(a, b)
  local idx = 1
  local max_idx = #a
  while a:byte(idx) == b:byte(idx) and idx <= max_idx do
    idx = idx + 1
  end

  return idx
end

function PromptCache:new(opts)
  self.__index = self
  local obj = setmetatable({
      current_line = nil,
      cached_results = {},
      cache_round = 0
  }, self)

  return obj
end

function PromptCache:set_cache(prompt, item_to_cache)
  self.results = item_to_cache
  self:_complete(prompt)
end

function PromptCache:_complete(prompt)
  if #prompt == 0 then
    self:_reset()
    return
  end

  local cached_lines = self.results

  local idx = 1
  if self.current_line ~= nil then
    idx = getFirstByteDiffIdx(self.current_line, prompt)
  end

  -- ABC
  -- ABDC
  -- IDX = 3
  -- cr = 3
  -- diff = 1
  local diff = #self.cached_results - (idx - 1)
  while diff > 0 do
    table.remove(self.cached_results)
    diff = diff - 1
  end

  -- ABC
  -- ADBC
  -- diff = 2
  for i = idx, #prompt do
    if #self.cached_results < (#prompt - 1) then
      local last_cache = self:get_last_cache()
      table.insert(self.cached_results, last_cache)
    else
      table.insert(self.cached_results, cached_lines)
    end
  end

  self.current_line = prompt
end

function PromptCache:start_round(cache_round)
  self.cache_round = cache_round
  log.trace("start_round (had this", self.results and #self.results or nil, "for past results)", self.cache_round)
  self.results = {}
end

function PromptCache:add_to_round(cache_round, line, score)
  if cache_round < self.cache_round or score == -1 then
    return
  end

  table.insert(self.results, line)
end

function PromptCache:get_last_cache()
  local last_cache = nil

  for idx = 1, #self.cached_results do
    local cache = self.cached_results[idx]
    if cache then
      last_cache = cache
    end
  end

  return last_cache
end

function PromptCache:complete_round(cache_round, prompt)
  if cache_round ~= self.cache_round then
    return
  end

  self:_complete(prompt)
end

function PromptCache:get_cache(prompt)
  if self.current_line == nil or #prompt == 0 then
    return nil
  end

  local idx = getFirstByteDiffIdx(self.current_line, prompt)

  if idx == 1 then
    self:_reset()
    return nil
  end

  -- if we are off, then we simply need to prune the cache or let complete do
  -- that
  local results = nil
  repeat
    results = self.cached_results[idx - 1]
    idx = idx - 1
  until idx <= 1 or results

return results
end

function PromptCache:_reset()
    self.current_line = nil
    self.cached_results = {}
end


return {
  PromptCache = PromptCache
}


