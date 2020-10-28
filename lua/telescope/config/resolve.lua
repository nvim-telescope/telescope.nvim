
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
    get_width = function(self, max_columns, max_lines) end
    get_height = function(self, max_columns, max_lines) end
  },

  total ?
}

!!NOT IMPLEMENTED YET!!

height =
    1. 0 <= number < 1
        This means total height as a percentage

    2. 1 <= number
        This means total height as a fixed number

    3. function(picker, columns, lines)
        -> returns one of the above options
        return max.min(110, max_rows * .5)

        if columns > 120 then
            return 110
        else
            return 0.6
        end

    3. {
        previewer = x,
        results = x,
        prompt = x,
    }, this means I do my best guess I can for these, given your options

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

local get_default = require('telescope.utils').get_default

local resolver = {}

local _resolve_map = {
  -- Booleans
  [function(val) return val == false end] = function(selector, val)
    return function(...)
      return val
    end
  end,

  -- Percentages
  [function(val) return type(val) == 'number' and val >= 0 and val < 1 end] = function(selector, val)
    return function(...)
      local selected = select(selector, ...)
      return math.floor(val * selected)
    end
  end,

  -- Numbers
  [function(val) return type(val) == 'number' and val >= 1 end] = function(selector, val)
    return function(...)
      local selected = select(selector, ...)
      return math.min(val, selected)
    end
  end,


  -- Tables TODO:
  -- ... {70, max}


  -- function:
  --    Function must have same signature as get_window_layout
  --        function(self, max_columns, max_lines): number
  --
  --    Resulting number is used for this configuration value.
  [function(val) return type(val) == 'function' end] = function(selector, val)
    return val
  end,
}

resolver.resolve_height = function(val)
  for k, v in pairs(_resolve_map) do
    if k(val) then
      return v(3, val)
    end
  end

  error('invalid configuration option for height:' .. tostring(val))
end

resolver.resolve_width = function(val)
  for k, v in pairs(_resolve_map) do
    if k(val) then
      return v(2, val)
    end
  end

  error('invalid configuration option for width:' .. tostring(val))
end

--- Win option always returns a table with preview, results, and prompt.
--- It handles many different ways. Some examples are as follows:
--
-- -- Disable
-- borderschars = false
--
-- -- All three windows share the same
-- borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└'},
--
-- -- Each window gets it's own configuration
-- borderchars = {
--   preview = {...},
--   results = {...},
--   prompt = {...},
-- }
--
-- -- Default to [1] but override with specific items
-- borderchars = {
--   {...}
--   prompt = {...},
-- }
resolver.win_option = function(val, default)
  if type(val) ~= 'table' or vim.tbl_islist(val) then
    if val == nil then
      val = default
    end

    return {
      preview = val,
      results = val,
      prompt = val,
    }
  elseif type(val) == 'table' then
    assert(not vim.tbl_islist(val))

    local val_to_set = val[1]
    if val_to_set == nil then
      val_to_set = default
    end

    return {
      preview = get_default(val.preview, val_to_set),
      results = get_default(val.results, val_to_set),
      prompt = get_default(val.prompt, val_to_set),
    }
  end
end

return resolver
