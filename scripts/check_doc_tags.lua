-- Checks that every |tag| reference in doc/*.txt points to a tag defined in doc/*.txt or in Nvim's
-- help (run with `nvim -l`, see `make docs`).

local docs = vim.fn.glob("doc/*.txt", false, true)

local tags = {} ---@type table<string, true>
for _, file in ipairs(docs) do
  for _, line in ipairs(vim.fn.readfile(file)) do
    for tag in line:gmatch("%*([^%s*|]+)%*") do
      tags[tag] = true
    end
  end
end
for _, line in ipairs(vim.fn.readfile(vim.fs.joinpath(vim.env.VIMRUNTIME, "doc", "tags"))) do
  tags[line:match("^[^\t]+")] = true
end

local broken = 0
for _, file in ipairs(docs) do
  local in_code = false
  for lnum, line in ipairs(vim.fn.readfile(file)) do
    if in_code then
      in_code = not (line:match("^<") or line:match("^%S"))
    end
    if not in_code then
      -- `"a"|"b"` in type annotations is not a reference
      for ref in line:gmatch('|([^%s|"]+)|') do
        if not tags[ref] then
          broken = broken + 1
          io.stderr:write(("%s:%d: unknown tag |%s|\n"):format(file, lnum, ref))
        end
      end
      in_code = line:match("%s>%a*$") ~= nil or line:match("^>%a*$") ~= nil
    end
  end
end

if broken > 0 then
  os.exit(1)
end
