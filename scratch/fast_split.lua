local test_line = "/home/tj/hello/world.lua"

local function fast_split(line, split)
  -- local split_line = vim.split(line, split)
  local areas = {}

  local processed = 1
  local line_length = #line + 1

  local part, start
  repeat
    start = string.find(line, split, processed, true) or line_length
    part = string.sub(line, processed, start - 1)

    if start - processed > 0 then
      table.insert(areas, {
        word = part,
        offset = processed
      })
    end

    processed = start + 1
  until start == line_length

  return areas
end

print(vim.inspect(fast_split(test_line, '/')))
