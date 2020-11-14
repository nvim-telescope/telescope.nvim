local make_entry = require('telescope.make_entry')
local shared = require('telescope.finders._shared')

local finder_obj = shared.finder_obj

--[[ =============================================================
Static Finders

A static finder has results that never change.
They are passed in directly as a result.
-- ============================================================= ]]
local StaticFinder = finder_obj()

function StaticFinder:new(opts)
  assert(opts, "Options are required. See documentation for usage")

  local input_results
  if vim.tbl_islist(opts) then
    input_results = opts
  else
    input_results = opts.results
  end

  local entry_maker = opts.entry_maker or make_entry.gen_from_string()

  assert(input_results)
  assert(input_results, "Results are required for static finder")
  assert(type(input_results) == 'table', "self.results must be a table")

  local results = {}
  for k, v in ipairs(input_results) do
    local entry = entry_maker(v)

    if entry then
      entry.index = k
      table.insert(results, entry)
    end
  end

  return setmetatable({ results = results }, self)
end

function StaticFinder:_find(_, process_result, process_complete)
  for _, v in ipairs(self.results) do
    process_result(v)
  end

  process_complete()
end


return StaticFinder
