
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

!!NOT IMPLEMENTED YET!!

height =
    1. pass between 0 & 1
        This means total height as a percentage

    2. pass a number > 1
        This means total height as a fixed number

    3. {
        previewer = x,
        results = x,
        prompt = x,
    }, this means I do my best guess I can for these, given your options

    4. function(max_rows)
        -> returns one of the above options
        return max.min(110, max_rows * .5)

        if columns > 120 then
            return 110
        else
            return 0.6
        end

width =
    exactly the same, but switch to width


{
    height = 0.5,
    width = {
        previewer = 0.25,
        results = 30,
    }
}

https://github.com/nvim-lua/telescope.nvim/pull/43

After we get layout, we should try and make top-down sorting work.
That's the next step to scrolling.

{
    vertical = {
    },
    horizontal = {
    },

    height = ...
    width = ...
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
