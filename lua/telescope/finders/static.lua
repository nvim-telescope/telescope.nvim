local co = coroutine

local Executor = require("telescope.finders.executor")
local make_entry = require('telescope.make_entry')

local StaticFinder = {}
StaticFinder.__index = StaticFinder

function StaticFinder:new(opts)
  assert(opts, "Options are required. See documentation for usage")

  local input_results = assert(opts.results)
  local entry_maker = opts.entry_maker or make_entry.gen_from_string()
  local operations = opts.operations or 1

  assert(type(input_results) == 'table', "results must be a table")

  local results = {}
  for k, v in ipairs(input_results) do
    local entry = entry_maker(v)

    if entry then
      entry.index = k
      table.insert(results, entry)
    end
  end

  return setmetatable({
    results = results,
    _operations = operations,
  }, self)
end

local try_idle = true
function StaticFinder:__call(_, process_result, process_complete)
  if not try_idle then
    return self:_find(_, process_result, process_complete)
  end

  print("CALLING STATIC FIND", _, process_result, process_complete)
  local executor = Executor:new(co.create(function()
    for index, v in ipairs(self.results) do
      process_result(v)
      co.yield()
    end

    process_complete()
  end))

  executor:run()
end

function StaticFinder:_find(_, process_result, process_complete)
  for _, v in ipairs(self.results) do
    process_result(v)
  end

  process_complete()
end

return StaticFinder
