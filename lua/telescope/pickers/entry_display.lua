local log = require('telescope.log')

local entry_display = {}

-- index are used to determine the correct order
-- elements = {
--   [1] = { element, max width }, -- max width should be greater than 0
--   [2] = { a, 0 } -- Use 0 to disable max width
--   [3] = { b, 0 } -- If b is nil, skip this column, should skip column for all rows
-- },
-- separator = " " -- either arbitrary string, when you wanna use the same separator between all elements
-- separator = { " ", ":" }  -- or table, where [1] is separator between elements[1] and elements[2], etc

-- TODO: Remove this and move ONLY to create method.

local table_format = function(picker, elements, separator)
  -- TODO: Truncate...
  local win_width = vim.api.nvim_win_get_width(picker.results_win)

  local output = ""
  for k, v in ipairs(elements) do
    local text = v[1]
    local width = v[2]
    if text ~= nil then
      if k > 1 then
        output = output .. (type(separator) == "table" and separator[k - 1] or separator)
      end
      if width then
        if width == 0 then
          output = output .. string.format("%s", text)
        elseif width < 1 then
          output = output .. string.format("%-" .. math.floor(width * win_width) .. "s", text)
        else
          output = output .. string.format("%-" .. width .."s", text)
        end
      else
        output = output .. text
      end
    end
  end
  return output
end

local function truncate(str, len)
  -- TODO: This doesn't handle multi byte chars...
  if vim.fn.strdisplaywidth(str) > len - 1 then
    str = str:sub(1, len)
    str = str .. "…"
  end
  return str
end

entry_display.create = function(configuration)
  local generator = {}
  for _, v in ipairs(configuration.items) do
    if v.width then
      local justify = not v.right_justify and "-" or ""
      local format_str = "%" .. justify .. v.width .. "s"
      table.insert(generator, function(item)
        return string.format(format_str, truncate(item, v.width))
      end)
    else
      table.insert(generator, function(item)
        return item
      end)
    end
  end

  return function(self, picker)
    local results = {}
    for k, v in ipairs(self) do
      table.insert(results, generator[k](v, picker))
    end

    return table.concat(results, configuration.separator or "│")
  end
end


entry_display.resolve = function(self, entry)
  local display, display_highlights
  if type(entry.display) == 'function' then
    self:_increment("display_fn")
    display, display_highlights = entry:display(self)

    if type(display) == 'string' then
      return display, display_highlights
    end
  else
    display = entry.display
  end

  if type(display) == 'string' then
    return display, display_highlights
  elseif type(display) == 'table' then
    return table_format(self, display, "│"), display_highlights
  end
end

return entry_display
