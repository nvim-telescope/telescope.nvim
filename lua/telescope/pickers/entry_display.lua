local utils = require('telescope.utils')

local entry_display = {}

entry_display.truncate = function(str, len)
  str = tostring(str) -- We need to make sure its an actually a string and not a number
  if utils.strdisplaywidth(str) <= len then
    return str
  end
  local charlen = 0
  local cur_len = 0
  local result = ''
  local len_of_dots = utils.strdisplaywidth('…')
  while true do
    local part = utils.strcharpart(str, charlen, 1)
    cur_len = cur_len + utils.strdisplaywidth(part)
    if (cur_len + len_of_dots) > len then
      result = result .. '…'
      break
    end
    result = result .. part
    charlen = charlen + 1
  end
  return result
end

entry_display.create = function(configuration)
  local generator = {}
  for _, v in ipairs(configuration.items) do
    if v.width then
      local justify = v.right_justify
      table.insert(generator, function(item)
        if type(item) == 'table' then
          return utils.align_str(entry_display.truncate(item[1], v.width), v.width, justify), item[2]
        else
          return utils.align_str(entry_display.truncate(item, v.width), v.width, justify)
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

          if type(hl) == "function" then
            for _, hl_res in ipairs(hl()) do
              table.insert(highlights, { { hl_res[1][1] + hl_start, hl_res[1][2] + hl_start }, hl_res[2] })
            end
          else
            table.insert(highlights, { { hl_start, hl_end }, hl })
          end
        end

        table.insert(results, str)
      end
    end

    if configuration.separator_hl then
      local width = #configuration.separator or 1

      local hl_start, hl_end
      for _, v in ipairs(results) do
        hl_start = (hl_end or 0) + #tostring(v)
        hl_end = hl_start + width
        table.insert(highlights, { { hl_start, hl_end }, configuration.separator_hl })
      end
    end

    local final_str = table.concat(results, configuration.separator or "│")
    if configuration.hl_chars then
      for i = 1, #final_str do
        local c = final_str:sub(i,i)
        local hl = configuration.hl_chars[c]
        if hl then
          table.insert(highlights, { { i - 1, i }, hl })
        end
      end
    end

    return final_str, highlights
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
  end
end

return entry_display
