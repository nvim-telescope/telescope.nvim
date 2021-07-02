---@tag telescope.actions.utils

---@brief [[
--- Utilities to wrap functions around picker selections and entries.
---
--- Generally used from within other |telescope.actions|
---@brief ]]

local action_state = require('telescope.actions.state')

local utils = {}

--- Apply `f` to the entries of the current picker and return a table of mapped entries.
--- - Note: mapped entries may include results not visible in the results popup.
---@param prompt_bufnr number: The prompt bufnr
---@param f function: Function to apply on entries of picker that takes (entry, index, row) as possible arguments
---@return table: Result from `f` applied to entries
function utils.map_entries(prompt_bufnr, f)
  vim.validate{
    f = {f, "function"}
  }
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local results = {}
  local index = 1
  local row, result
    -- indices are 1-indexed, rows are 0-indexed
  for entry in current_picker.manager:iter() do
    row = current_picker:get_row(index)
    -- assign result to variable as function w/o return value
    -- results in error upon table.insert as it's not technically nil but 'empty'
    result = f(entry, index, row)
    results[index] = result
    index = index + 1
  end
  return results
end

--- Apply `f` to the multi selections of the current picker and return a table of mapped selections.
---@param prompt_bufnr number: The prompt bufnr
---@param f function: Function to apply on multi selection of picker
---@return table: Result from `f` applied to selections
function utils.map_selections(prompt_bufnr, f)
  vim.validate{
    f = {f, "function"}
  }
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local results = {}
  local result
  for _, selection in ipairs(current_picker:get_multi_selection()) do
    result = f(selection)
    -- assign result to variable as function w/o return value
    -- results in error upon table.insert as it's not technically nil but 'empty'
    table.insert(results, result)
  end
  return results
end

return utils
