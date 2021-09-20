local bench = require "plenary.benchmark"
local fzf = require "fzf_lib"
local CEntryManager = require "telescope.c_entry_manager"
local EntryManager = require "telescope.entry_manager"

local function lines_from(file)
  local lines = {}
  for line in io.lines(file) do
    lines[#lines + 1] = line
  end
  return lines
end

local function filter(manager, prompt, lines)
  local slab = fzf.allocate_slab()
  local p = fzf.parse_pattern(prompt, 0)
  for _, line in ipairs(lines) do
    manager:add_entry({}, fzf.get_score(line, p, slab), { value = line, display = line, ordinal = line })
  end
  fzf.free_pattern(p)
  fzf.free_slab(slab)

  return manager:num_results()
end

local lines = lines_from "../telescope-fzf-native.nvim/files"

local max = 10000

bench("lua vs c ffi", {
  warmup = 3,
  runs = 10,
  fun = {
    {
      "c ffi",
      function()
        local c_manager = CEntryManager:new(max)
        filter(c_manager, "fzf.c", lines)
      end,
    },
    {
      "lua",
      function()
        local manager = EntryManager:new(max)
        filter(manager, "fzf.c", lines)
      end,
    },
  },
})
