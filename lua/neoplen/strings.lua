local fn = vim.fn

local M = {}

local truncate = function(str, len, dots, direction)
  if fn.strdisplaywidth(str) <= len then
    return str
  end
  local start = direction > 0 and 0 or str:len()
  local current = 0
  local result = ""
  local len_of_dots = fn.strdisplaywidth(dots)
  local concat = function(a, b, dir)
    if dir > 0 then
      return a .. b
    else
      return b .. a
    end
  end
  while true do
    local part = fn.strcharpart(str, start, 1)
    current = current + fn.strdisplaywidth(part)
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
    if fn.strdisplaywidth(str) <= len then
      return str
    end
    local len1 = math.floor((len + fn.strdisplaywidth(dots)) / 2)
    local s1 = truncate(str, len1, dots, 1)
    local len2 = len - fn.strdisplaywidth(s1) + fn.strdisplaywidth(dots)
    local s2 = truncate(str, len2, dots, -1)
    return s1 .. s2:sub(dots:len() + 1)
  end
end

M.align_str = function(string, width, right_justify)
  local str_len = fn.strdisplaywidth(string)
  return right_justify and string.rep(" ", width - str_len) .. string or string .. string.rep(" ", width - str_len)
end

return M
