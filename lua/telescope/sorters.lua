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

return sorters
