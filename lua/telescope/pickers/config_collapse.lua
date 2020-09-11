
--[[

Ultimately boils down to getting `height` and `width` for:
- prompt
- preview
- results

No matter what you do, I will not make prompt have more than one line (atm)

Result of `resolve` should be a table with:

{
  preview = {
    get_width = function(self, max_columns, max_lines) end
    get_height = function(self, max_columns, max_lines) end
  },

  result = {
    get_width = function(self, max_columns, max_lines) end
    get_height = function(self, max_columns, max_lines) end
  },

  prompt = {
    get_width = function(self, max_columns, max_lines) return 1end
    get_height = function(self, max_columns, max_lines) end
  },
}

--]]

local resolver = {}

local percentage_resolver = function(selector, percentage)
  assert(percentage <= 1)
  assert(percentage >= 0)

  return function(...)
    return percentage * select(selector, ...)
  end
end

resolver.resolve_percentage_height = function(percentage)
  return percentage_resolver(3, percentage)
end

resolver.resolve_percentage_width = function(percentage)
  return percentage_resolver(2, percentage)
end

return resolver
