local log = require('telescope.log')
local util = require('telescope.utils')

local sorters = {}

local ngram_highlighter = function(ngram_len, prompt, display)
  local highlights = {}
  display = display:lower()

  for disp_index = 1, #display do
    local char = display:sub(disp_index, disp_index + ngram_len - 1)
    if prompt:find(char, 1, true) then
      table.insert(highlights, {
        start = disp_index,
        finish = disp_index + ngram_len - 1
      })
    end
  end

  return highlights
end


local Sorter = {}
Sorter.__index = Sorter

---@class Sorter
--- Sorter sorts a list of results by return a single integer for a line,
--- given a prompt
---
--- Lower number is better (because it's like a closer match)
--- But, any number below 0 means you want that line filtered out.
--- @field scoring_function function Function that has the interface:
--      (sorter, prompt, line): number
function Sorter:new(opts)
  opts = opts or {}

  return setmetatable({
    state = {},
    scoring_function = opts.scoring_function,
    highlighter = opts.highlighter,
  }, Sorter)
end

function Sorter:score(prompt, entry)
  if not entry or not entry.ordinal then return -1 end
  return self:scoring_function(prompt or "", entry.ordinal, entry)
end

function sorters.new(...)
  return Sorter:new(...)
end

sorters.Sorter = Sorter

TelescopeCachedTails = TelescopeCachedTails or nil
if not TelescopeCachedTails then
  local os_sep = util.get_separator()
  local match_string = '[^' .. os_sep .. ']*$'
  TelescopeCachedTails = setmetatable({}, {
    __index = function(t, k)
      local tail = string.match(k, match_string)

      rawset(t, k, tail)
      return tail
    end,
  })
end

TelescopeCachedUppers = TelescopeCachedUppers or setmetatable({}, {
  __index = function(t, k)
    local obj = {}
    for i = 1, #k do
      local s_byte = k:byte(i, i)
      if s_byte <= 90 and s_byte >= 65 then
        obj[s_byte] = true
      end
    end

    rawset(t, k, obj)
    return obj
  end
})

TelescopeCachedNgrams = TelescopeCachedNgrams or {}

-- TODO: Match on upper case words
-- TODO: Match on last match
sorters.get_fuzzy_file = function(opts)
  opts = opts or {}

  local ngram_len = opts.ngram_len or 2

  local function overlapping_ngrams(s, n)
    if TelescopeCachedNgrams[s] and TelescopeCachedNgrams[s][n] then
      return TelescopeCachedNgrams[s][n]
    end

    local R = {}
    for i = 1, s:len() - n + 1 do
      R[#R+1] = s:sub(i, i+n-1)
    end

    if not TelescopeCachedNgrams[s] then
      TelescopeCachedNgrams[s] = {}
    end

    TelescopeCachedNgrams[s][n] = R

    return R
  end

  return Sorter:new {
    scoring_function = function(_, prompt, line)
      local N = #prompt

      if N == 0 or N < ngram_len then
        -- TODO: If the character is in the line,
        -- then it should get a point or somethin.
        return 0
      end

      local prompt_lower = prompt:lower()
      local line_lower = line:lower()

      local prompt_lower_ngrams = overlapping_ngrams(prompt_lower, ngram_len)

      -- Contains the original string
      local contains_string = line_lower:find(prompt_lower, 1, true)

      local prompt_uppers = TelescopeCachedUppers[prompt]
      local line_uppers = TelescopeCachedUppers[line]

      local uppers_matching = 0
      for k, _ in pairs(prompt_uppers) do
        if line_uppers[k] then
          uppers_matching = uppers_matching + 1
        end
      end

      -- TODO: Consider case senstivity
      local tail = TelescopeCachedTails[line_lower]
      local contains_tail = tail:find(prompt, 1, true)

      local consecutive_matches = 0
      local previous_match_index = 0
      local match_count = 0

      for i = 1, #prompt_lower_ngrams do
        local match_start = line_lower:find(prompt_lower_ngrams[i], 1, true)
        if match_start then
          match_count = match_count + 1
          if match_start > previous_match_index then
            consecutive_matches = consecutive_matches + 1
          end

          previous_match_index = match_start
        end
      end

      local tail_modifier = 1
      if contains_tail then
        tail_modifier = 2
      end

      local denominator = (
        (10 * match_count / #prompt_lower_ngrams)
        -- biases for shorter strings
        + 3 * match_count * ngram_len / #line
        + consecutive_matches
        + N / (contains_string or (2 * #line))

        -- + 30/(c1 or 2*N)

        -- TODO: It might be possible that this too strongly correlates,
        --          but it's unlikely for people to type capital letters without actually
        --          wanting to do something with a capital letter in it.
        + uppers_matching
      ) * tail_modifier

      if denominator == 0 or denominator ~= denominator then
        return -1
      end

      if #prompt > 2 and denominator < 0.5 then
        return -1
      end

      return 1 / denominator
    end,

    highlighter = opts.highlighter or function(_, prompt, display)
      return ngram_highlighter(ngram_len, prompt, display)
    end,
  }
end

sorters.get_generic_fuzzy_sorter = function(opts)
  opts = opts or {}

  local ngram_len = opts.ngram_len or 2

  local function overlapping_ngrams(s, n)
    if TelescopeCachedNgrams[s] and TelescopeCachedNgrams[s][n] then
      return TelescopeCachedNgrams[s][n]
    end

    local R = {}
    for i = 1, s:len() - n + 1 do
      R[#R+1] = s:sub(i, i+n-1)
    end

    if not TelescopeCachedNgrams[s] then
      TelescopeCachedNgrams[s] = {}
    end

    TelescopeCachedNgrams[s][n] = R

    return R
  end

  return Sorter:new {
    -- self
    -- prompt (which is the text on the line)
    -- line (entry.ordinal)
    -- entry (the whole entry)
    scoring_function = function(_, prompt, line, _)
      if prompt == 0 or #prompt < ngram_len then
        return 0
      end

      local prompt_lower = prompt:lower()
      local line_lower = line:lower()

      local prompt_ngrams = overlapping_ngrams(prompt_lower, ngram_len)

      local N = #prompt

      local contains_string = line_lower:find(prompt_lower, 1, true)

      local consecutive_matches = 0
      local previous_match_index = 0
      local match_count = 0

      for i = 1, #prompt_ngrams do
        local match_start = line_lower:find(prompt_ngrams[i], 1, true)
        if match_start then
          match_count = match_count + 1
          if match_start > previous_match_index then
            consecutive_matches = consecutive_matches + 1
          end

          previous_match_index = match_start
        end
      end

      -- TODO: Copied from ashkan.
      local denominator = (
        (10 * match_count / #prompt_ngrams)
        -- biases for shorter strings
        -- TODO(ashkan): this can bias towards repeated finds of the same
        -- subpattern with overlapping_ngrams
        + 3 * match_count * ngram_len / #line
        + consecutive_matches
        + N / (contains_string or (2 * #line))
        -- + 30/(c1 or 2*N)
      )

      if denominator == 0 or denominator ~= denominator then
        return -1
      end

      if #prompt > 2 and denominator < 0.5 then
        return -1
      end

      return 1 / denominator
    end,

    highlighter = opts.highlighter or function(_, prompt, display)
      return ngram_highlighter(ngram_len, prompt, display)
    end,
  }
end

sorters.fuzzy_with_index_bias = function(opts)
  opts = opts or {}
  opts.ngram_len = 2

  -- TODO: Probably could use a better sorter here.
  local fuzzy_sorter = sorters.get_generic_fuzzy_sorter(opts)

  return Sorter:new {
    scoring_function = function(_, prompt, _, entry)
      local base_score = fuzzy_sorter:score(prompt, entry)

      if base_score == -1 then
        return -1
      end

      if base_score == 0 then
        return entry.index
      else
        return math.min(math.pow(entry.index, 0.25), 2) * base_score
      end
    end
  }
end

-- Bad & Dumb Sorter
sorters.get_levenshtein_sorter = function()
  return Sorter:new {
    scoring_function = function(_, prompt, line)
      return require('telescope.algos.string_distance')(prompt, line)
    end
  }
end

return sorters
