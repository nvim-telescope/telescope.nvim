local M = {}

M.strdisplaywidth = vim.fn.strdisplaywidth

local truncate = function(str, len, dots, direction)
  if M.strdisplaywidth(str) <= len then
    return str
  end
  local start = direction > 0 and 0 or str:len()
  local current = 0
  local result = ""
  local len_of_dots = M.strdisplaywidth(dots)
  local concat = function(a, b, dir)
    if dir > 0 then
      return a .. b
    else
      return b .. a
    end
  end
  while true do
    local part = vim.fn.strcharpart(str, start, 1)
    current = current + M.strdisplaywidth(part)
    if (current + len_of_dots) > len then
      result = concat(result, dots, direction)
      break
    end
    result = concat(result, part, direction)
    start = start + direction
  end
  return result
end

M.truncate = function(str, len, dots, direction)
  str = tostring(str) -- We need to make sure its an actually a string and not a number
  dots = dots or "…"
  direction = direction or 1
  if direction ~= 0 then
    return truncate(str, len, dots, direction)
  else
    if M.strdisplaywidth(str) <= len then
      return str
    end
    local len1 = math.floor((len + M.strdisplaywidth(dots)) / 2)
    local s1 = truncate(str, len1, dots, 1)
    local len2 = len - M.strdisplaywidth(s1) + M.strdisplaywidth(dots)
    local s2 = truncate(str, len2, dots, -1)
    return s1 .. s2:sub(dots:len() + 1)
  end
end

M.align_str = function(string, width, right_justify)
  local str_len = M.strdisplaywidth(string)
  return right_justify and string.rep(" ", width - str_len) .. string or string .. string.rep(" ", width - str_len)
end

M.dedent = function(str, leave_indent)
  -- Check each line and detect the minimum indent.
  local indent
  local info = {}
  for line in str:gmatch "[^\n]*\n?" do
    -- It matches '' for the last line.
    if line ~= "" then
      local chars, width
      local line_indent = line:match "^[ \t]+"
      if line_indent then
        chars = #line_indent
        width = M.strdisplaywidth(line_indent)
        if not indent or width < indent then
          indent = width
        end
      -- Ignore empty lines
      elseif line ~= "\n" then
        indent = 0
      end
      table.insert(info, { line = line, chars = chars, width = width })
    end
  end

  -- Build up the result
  leave_indent = leave_indent or 0
  local result = {}
  for _, i in ipairs(info) do
    local line
    if i.chars then
      local content = i.line:sub(i.chars + 1)
      local indent_width = i.width - indent + leave_indent
      line = (" "):rep(indent_width) .. content
    elseif i.line == "\n" then
      line = "\n"
    else
      line = (" "):rep(leave_indent) .. i.line
    end
    table.insert(result, line)
  end
  return table.concat(result)
end

return M
