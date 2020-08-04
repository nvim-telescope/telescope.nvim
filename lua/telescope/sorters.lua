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
--- @param scoring_function function Function that has the interface:
--      (sorter, prompt, line): number
function Sorter:new(opts)
  opts = opts or {}

  return setmetatable({
    state = {},
    scoring_function = opts.scoring_function,
  }, Sorter)
end

function Sorter:score(prompt, line)
  return self:scoring_function(prompt, line)
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

return sorters
