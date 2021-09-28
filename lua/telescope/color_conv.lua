local conv = {}

local color_cache = {}

-- gen_hl_groups is inspired by: https://github.com/norcalli/nvim-terminal.lua
local gen_hl_groups = function()
  local color_table = {}
  if not vim.o.termguicolors then
    -- https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
    local rgb_to_hex = function(r, g, b) return ("#%02X%02X%02X"):format(r,g,b) end
    local cube6 = function(v) return v == 0 and v or (v * 40 + 55) end
    color_table = { [0] = "#000000", "#AA0000", "#00AA00", "#AA5500", "#0000AA", "#AA00AA", "#00AAAA", "#AAAAAA",
                          "#555555", "#FF5555", "#55FF55", "#FFFF55", "#5555FF", "#FF55FF", "#55FFFF", "#FFFFFF" }

    for b = 0, 5 do
      for g = 0, 5 do
        for r = 0, 5 do
          local i = 16 + 36 * r + 6 * g + b
          color_table[i] = rgb_to_hex(cube6(r), cube6(g), cube6(b))
        end
      end
    end
    for i = 0, 23 do
      local v = 8 + (i * 10)
      color_table[232 + i] = rgb_to_hex(v, v, v)
    end
  else
    for i = 0, 255 do
      local ok, v = pcall(vim.api.nvim_get_var, 'terminal_color_' .. i)
      if ok then
        color_table[i] = v
      end
    end
  end

  local att = {}
  for i = 1, 255 do -- For our alg we don't have to create [0m
    if i >= 30 and i <= 37 then
      -- Foreground color
      local ctermfg = i - 30
      att.ctermfg = ctermfg
      att.guifg = color_table[ctermfg]
    elseif i >= 40 and i <= 47 then
      -- Background color
      local ctermbg = i - 40
      att.ctermbg = ctermbg
      att.guibg = color_table[ctermbg]
    elseif i >= 90 and i <= 97 then
      -- Bright colors. Foreground
      local ctermfg = i - 90 + 8
      att.ctermfg = ctermfg
      att.guifg = color_table[ctermfg]
    elseif i >= 100 and i <= 107 then
      -- Bright colors. Background
      local ctermbg = i - 100 + 8
      att.ctermbg = ctermbg
      att.guibg = color_table[ctermbg]
    elseif i == 22 then
      att.cterm = 'NONE'
      att.gui = 'NONE'
    elseif i == 39 then
      -- Reset to normal color for foreground
      att.ctermfg = 'NONE'
      att.guifg = 'NONE'
    elseif i == 49 then
      -- Reset to normal color for background
      att.ctermbg = 'NONE'
      att.guibg = 'NONE'
    elseif i == 1 then
      att.cterm = 'bold'
      att.gui = 'bold'
    end

    local name = 'plenary_term_' .. i
    name = 'DevIconLua'
    local cmd = 'hi ' .. name
    for a, h in pairs(att) do
      cmd = cmd .. ' ' .. a .. '=' .. h
    end
    vim.cmd(cmd)
    color_cache[i] = name
  end
end

local get_hl_group = function(code)
  if table.getn(color_cache) == 0 then gen_hl_groups() end

  code = code:sub(1, -2) -- Remove m

  if code:sub(3, 5) == ';5;' or code:sub(3, 5) == ':5:' or
     code:sub(3, 5) == ';2;' or code:sub(3, 5) == ':2:' then
     error('Currently not supported for ;5; or ;2;')
  end

  if code:sub(1, 2) == "0;" then code = code:sub(3, -1) end

  local sem_start, _ = code:find(';1') -- Bright color support
  if sem_start then
    code = tonumber(code:sub(1, sem_start - 1)) + 60
  end

  return color_cache[tonumber(code)]
end

-- Function for testing
conv._reset_table = function() color_cache = {} end

conv.remove_termcodes = function(content)
  local res_lines = {}
  for k, v in ipairs(content) do
    res_lines[k] = v:gsub('%[[0-9;]*m', '')
  end
  return res_lines
end

conv.interpret_termcodes = function(content, fetch_hl)
  local res_lines = {}
  local highlights = {}

  local add_highlight = function(l, s, e, hl)
    if s == e then return end
    --table.insert(highlights, { line = l, hl_start = s, hl_end = e, hl_group = hl })
    table.insert(highlights, { {s,e}, hl})
  end

  for k, v in ipairs(content) do
    local line = ""
    local text_section = ""
    local current_color, hl_start
    local new_default_start = 1
    local processed_chars = 0
    local escape_code_l = 2

    repeat
      --local _, s = v:find([[]])
      local _, s = v:find( '%[' )
      if s then
        -- escape code + [ are 2 characters
        text_section = v:sub(1, s - escape_code_l)

        line = line .. text_section
        new_default_start = new_default_start + s - escape_code_l
        if current_color then
          processed_chars = processed_chars + s - escape_code_l
        end

        v = v:sub(s + 1, -1)
        local _, e = v:find('m')
        local color = v:sub(2, e)
        v = v:sub(e + 1, -1)

        if not current_color then
          hl_start = new_default_start
          current_color = color
        else
          if color == '0m' then
            --add_highlight(k, hl_start, hl_start + processed_chars, get_hl_group(current_color))
            add_highlight(k, hl_start, hl_start + processed_chars, fetch_hl( current_color ))
            current_color = nil
            hl_start = nil
            processed_chars = 0
          else
            if fetch_hl(current_color) then
              --add_highlight(k, hl_start, hl_start + processed_chars, get_hl_group(current_color))
                add_highlight(k, hl_start, hl_start + processed_chars, fetch_hl( current_color ))
            end
            hl_start = new_default_start
            current_color = color
            processed_chars = 0
          end
        end
      else
        line = line .. v:sub(1, #v)
        break
      end
    until v == ''
    res_lines[k] = line
  end

  return res_lines, highlights
end

return conv
