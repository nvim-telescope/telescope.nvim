local _async = require "telescope._async"

local make_entry = require "telescope.make_entry"

return function(opts)
  local input_results
  if vim.islist(opts) then
    input_results = opts
  else
    input_results = opts.results
  end

  local entry_maker = opts.entry_maker or make_entry.gen_from_string(opts)

  local results = {}
  for k, v in ipairs(input_results) do
    local entry = entry_maker(v)

    if entry then
      entry.index = k
      table.insert(results, entry)
    end
  end

  ---@async
  local function find(_, _, process_result, process_complete)
    _async.process_list(results, #results, process_result)
    process_complete()
  end

  return setmetatable({
    results = results,
    entry_maker = entry_maker,
    -- results don't depend on the prompt (allows narrowing, see `Picker:_narrowed_candidates`)
    prompt_independent = true,
    close = function() end,
  }, {
    __call = find,
  })
end
