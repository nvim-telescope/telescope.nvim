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
  if vim.fn.strdisplaywidth(str) > len then
    str = str:sub(1, len - 1)
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
        if type(item) == 'table' then
          return string.format(format_str, truncate(item[1], v.width)), item[2]
        else
          return string.format(format_str, truncate(item, v.width))
        end
      end)
    else
      table.insert(generator, function(item)
        if type(item) == 'table' then
          return item[1], item[2]
        else
          return item
        end
      end)
    end
  end

  return function(self, picker)
    local results = {}
    local highlights = {}
    for i = 1, table.getn(generator) do
      if self[i] ~= nil then
        local str, hl = generator[i](self[i], picker)
        if hl then
          local hl_start = 0
          for j = 1, (i - 1) do
            hl_start = hl_start + #results[j] + (#configuration.separator or 1)
          end
          local hl_end = hl_start + #str:gsub('%s*$', '')
          table.insert(highlights, { { hl_start, hl_end }, hl })
        end
        table.insert(results, str)
      end
    end

    if configuration.separator_hl then
      local width = #configuration.separator or 1
      local hl_start, hl_end = 0, 0
      for _, v in ipairs(results) do
        hl_start = hl_end + #tostring(v)
        hl_end = hl_start + width
        table.insert(highlights, { { hl_start, hl_end }, configuration.separator_hl })
      end
    end

    return table.concat(results, configuration.separator or "│"), highlights
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
