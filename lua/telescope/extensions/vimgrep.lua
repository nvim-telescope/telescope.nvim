local vimgrep = {}

vimgrep.parse_line = function(line)
  local sections = vim.split(line, ":")

  return {
    filename = sections[1],
    row = tonumber(sections[2]),
    col = tonumber(sections[3]),
  }
end

return vimgrep
