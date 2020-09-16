local log = require('telescope.log')

local M = {}

local current_request_id = nil

local request_id_to_picker = setmetatable({}, {
  __mode = 'kv'
})

local max_entry_id = 0
local entry_id_to_entry = {}

local function worker_func(path, bound_request_id, entry_id, prompt, entry)
  package.path = path

  if not FuzzySorter then
    FuzzySorter = require('telescope.sorters').get_fuzzy_file()
  end

  return bound_request_id, entry_id, pcall(FuzzySorter.score, FuzzySorter, prompt, entry)
end

local function after_func(bound_request_id, entry_id, score_ok, sort_score)
  local picker = request_id_to_picker[bound_request_id]

  if picker._requests_id ~= bound_request_id or bound_request_id ~= current_request_id then
    return
  end

  -- TODO: we should totally make sure that this picker is still doing stuff...
  -- it could otherwise be done.
  if not score_ok or sort_score == -1 then
    picker._requests_in_flight = picker._requests_in_flight - 1
    return
  end

  local entry = entry_id_to_entry[entry_id]
  entry_id_to_entry[entry_id] = nil

  picker.manager:add_entry(sort_score, entry)
end

local worker = vim.loop.new_work(worker_func, after_func)


function M.score_entry(bound_request_id, prompt, entry, picker)
  current_request_id = bound_request_id

  request_id_to_picker[bound_request_id] = picker

  max_entry_id = max_entry_id + 1
  entry_id_to_entry[max_entry_id] = entry

  worker:queue(package.path, bound_request_id, max_entry_id, prompt, type(entry) == "string" and entry or entry.ordinal)
end

return M
