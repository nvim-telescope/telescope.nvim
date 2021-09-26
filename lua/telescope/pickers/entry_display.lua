local strings = require "plenary.strings"

local entry_display = {}
entry_display.truncate = strings.truncate

---@tag telescope.pickers.entry_display

---@brief [[
--- Entry Display is used to format each entry shown in the result panel.
---
--- Entry Display create() will give us a function based on the configuration
--- of column widths we pass into to it. We then can use this function n times 
--- to return a string based on structured input.
---
--- The create function will use the column widths passed to it in
--- configaration.items. Each item in that table is the number of characters in
--- the column. It's also possible for the final column to not have a fixed width,
--- this will be shown in the configuartion as 'remaining = true'.
---
--- An example of this configuration is shown for the buffers picker
---
---   local displayer = entry_display.create {
---     separator = " ",
---     items = {
---       { width = opts.bufnr_width },
---       { width = 4 },
---       { width = icon_width },
---       { remaining = true },
---     },
---   }
---
--- This shows 4 columns, the first is defined in the opts as the width we'll use when display_string
--- the number of the buffer. The second has a fixed width of 4 and the 3rd column's widht will be 
--- decided by the width of the icons we use. The fourth column will use the remaining space.
--- Finally we have also defined the seperator between each column will be the space " ".
---
---
--- It's best practice for pickers to store the function returned by create() in a reference
--- called display. This function is called for every entry which is displayed and passes in the
--- actual text which should be used to create the string displayed for the entry.
--- The text is passed in as a table, the number of items will match the number of columns.
--- Each item can be a string or a table containing the text along with the highlight color.
---
--- An example of how the display reference will be used is shown, again for the buffers picker:
---
--- return displayer {
---   { entry.bufnr, "TelescopeResultsNumber" },
---   { entry.indicator, "TelescopeResultsComment" },
---   { icon, hl_group },
---   display_bufname .. ":" .. entry.lnum,
--- }
---
--- The displayer can return values, final_str and an optional highlights.
--- final_str is all the text to be displayed for this entry as a single string. If parts of the
--- string are to be highlighted they will be described in the highlights table.
---
--- For better understanding of how create() and displayer are used it's best to look
--- at the code in make_entry.lua.
---
---@brief ]]

entry_display.create = function(configuration)
  local generator = {}
  for _, v in ipairs(configuration.items) do
    if v.width then
      local justify = v.right_justify
      table.insert(generator, function(item)
        if type(item) == "table" then
          return strings.align_str(entry_display.truncate(item[1], v.width), v.width, justify), item[2]
        else
          return strings.align_str(entry_display.truncate(item, v.width), v.width, justify)
        end
      end)
    else
      table.insert(generator, function(item)
        if type(item) == "table" then
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
          local hl_end = hl_start + #str:gsub("%s*$", "")

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
        local c = final_str:sub(i, i)
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
  if type(entry.display) == "function" then
    self:_increment "display_fn"
    display, display_highlights = entry:display(self)

    if type(display) == "string" then
      return display, display_highlights
    end
  else
    display = entry.display
  end

  if type(display) == "string" then
    return display, display_highlights
  end
end

return entry_display
