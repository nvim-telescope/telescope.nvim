local start = vim.loop.hrtime()

local counts = 1e6
for _ = 1, counts do
  local _ = vim.loop.hrtime()
end

print(counts, ":", (vim.loop.hrtime() - start) / 1e9)
