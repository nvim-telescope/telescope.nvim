local log = require('telescope.log')
local util = require('telescope.utils')

local sorters = {}


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
  }, Sorter)
end

function Sorter:score(prompt, entry)
  -- TODO: Decide if we actually want to check the type every time.
  return self:scoring_function(prompt, type(entry) == "string" and entry or entry.ordinal)
end

function sorters.new(...)
  return Sorter:new(...)
end

sorters.Sorter = Sorter

sorters.get_ngram_sorter = function()
  return Sorter:new {
    scoring_function = function(_, prompt, line)
      if prompt == "" or prompt == nil then
        return 1
      end

      local ok, result = pcall(function()
        local ngram = util.new_ngram { N = 4 }
        ngram:add(line)

        local score = ngram:score(prompt)
        if score == 0 then
          return -1
        end

        -- return math.pow(math.max(score, 0.0001), -1)
        return score
      end)

      print(prompt, line, result)
      return ok and result or 1
    end
  }
end

sorters.get_levenshtein_sorter = function()
  return Sorter:new {
    scoring_function = function(_, prompt, line)
      local result = require('telescope.algos.string_distance')(prompt, line)
      log.info("Sorting result for", prompt, line, " = ", result)
      return result
    end
  }
end

-- TODO: Match on upper case words
-- TODO: Match on last match
sorters.get_fuzzy_file = function()
  local cached_tails = {}
  local cached_ngrams = {}

  return Sorter:new {
    scoring_function = function(_, prompt, line)
      return 1
    end
  }
end

sorters.get_norcalli_sorter = function()
  local ngramlen = 2

  local cached_ngrams = {}

  local function overlapping_ngrams(s, n)
    if cached_ngrams[s] and cached_ngrams[s][n] then
      return cached_ngrams[s][n]
    end

    local R = {}
    for i = 1, s:len() - n + 1 do
      R[#R+1] = s:sub(i, i+n-1)
    end

    if not cached_ngrams[s] then
      cached_ngrams[s] = {}
    end

    cached_ngrams[s][n] = R

    return R
  end

  return Sorter:new {
    scoring_function = function(_, prompt, line)
      if prompt == 0 or #prompt < ngramlen then
        return 0
      end

      local prompt_lower = prompt:lower()
      local line_lower = line:lower()

      local prompt_ngrams = overlapping_ngrams(prompt_lower, ngramlen)

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
        + 3 * match_count * ngramlen / #line
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
    end
  }
end

return sorters
