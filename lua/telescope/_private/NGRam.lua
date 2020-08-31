local NGram = {}
NGram.__index = NGram

function NGram:new(opts)
  -- TODO: Add padding
  opts = opts or {}
  return setmetatable({
    N = opts.N or 2,
    split = opts.split or "/",
    _depth = 5,
    _grams = setmetatable({}, utils.default_table_mt)
  }, self)
end

local min = math.min

function NGram:_split(word)
  local word_len = #word

  local result = {}
  for i = 1, word_len - 1 do
    -- for j = i + (self.N - 1), min(i + self._depth - 1, word_len) do
    --   table.insert(result, string.sub(word, i, j))
    -- end
    table.insert(result, string.sub(word, i, i + self.N - 1))
  end

  return result
end

-- local function pairsByKeys (t, f)
--   local a = {}
--   for n in pairs(t) do table.insert(a, n) end
--   table.sort(a, f)
--   local i = 0      -- iterator variable
--   local iter = function ()   -- iterator function
--     i = i + 1
--     if a[i] == nil then return nil
--     else return a[i], t[a[i]]
--     end
--   end
--   return iter
-- end

function NGram:add(word)
  local split_word = self:_split(word)

  for _, k in ipairs(split_word) do
    local counts = self._grams[k]
    if counts[word] == nil then
      counts[word] = 0
    end

    counts[word] = counts[word] + 1
  end
end

function NGram:_items_sharing_ngrams(query)
  local split_query = self:_split(query)

  -- Matched string to number of N-grams shared with the query string.
  local shared = {}

  local remaining = {}

  for _, ngram in ipairs(split_query) do
    remaining = {}
    for match, count in pairs(self._grams[ngram] or {}) do
      remaining[match] = remaining[match] or count

      if remaining[match] > 0 then
        remaining[match] = remaining[match] - 1
        shared[match] = (shared[match] or 0) + 1
      end
    end
  end

  return shared
end

function NGram:search(query, show_values)
  local sharing_ngrams = self:_items_sharing_ngrams(query)

  local results = {}
  for name, count in pairs(sharing_ngrams) do
    local allgrams = #query + #name - (2 * self.N) - count + 2
    table.insert(results, {name, count / allgrams})
  end

  table.sort(results, function(left, right)
    return left[2] > right[2]
  end)

  if not show_values then
    for k, v in ipairs(results) do
      results[k] = v[1]
    end
  end

  return results
end

function NGram:find(query)
  return self:search(query)[1]
end

function NGram:score(query)
  return (self:search(query, true)[1] or {})[2] or 0
end
