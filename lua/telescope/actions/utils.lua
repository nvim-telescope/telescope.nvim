---@tag telescope.actions.utils

---@brief [[
--- Utilities to wrap functions around picker selections and entries.
---
--- Generally used from within other |telescope.actions|
---@brief ]]

local action_state = require('telescope.actions.state')

local utils = {}

--- Apply `f` to the entries of the current picker.
--- - Notes:
---   - Mapped entries may include results not visible in the results popup.
---   - Indices are 1-indexed, whereas rows are 0-indexed.
--- - Warning: `map_entries` has no return value.
---   - The below example showcases how to collect results
--- <pre>
--- Usage:
---     local action_state = require "telescope.actions.state"
---     local action_utils = require "telescope.actions.utils"
---     function entry_value_by_row()
---       local prompt_bufnr = vim.api.nvim_get_current_buf()
---       local current_picker = action_state.get_current_picker(prompt_bufnr)
---       local results = {}
---         action_utils.map_entries(prompt_bufnr, function(entry, index, row)
---         results[row] = entry.value
---       end)
---       return results
---     end
--- </pre>
---@param prompt_bufnr number: The prompt bufnr
---@param f function: Function to map onto entries of picker that takes (entry, index, row) as viable arguments
function utils.map_entries(prompt_bufnr, f)
  vim.validate{
    f = {f, "function"}
  }
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local index = 1
    -- indices are 1-indexed, rows are 0-indexed
  for entry in current_picker.manager:iter() do
    local row = current_picker:get_row(index)
    f(entry, index, row)
    index = index + 1
  end
end

--- Apply `f` to the multi selections of the current picker and return a table of mapped selections.
--- - Notes:
---   - Mapped selections may include results not visible in the results popup.
---   - Selected entries are returned in order of their selection.
--- - Warning: `map_selections` has no return value.
---   - The below example showcases how to collect results
--- <pre>
--- Usage:
---     local action_state = require "telescope.actions.state"
---     local action_utils = require "telescope.actions.utils"
---     function selection_by_index()
---       local prompt_bufnr = vim.api.nvim_get_current_buf()
---       local current_picker = action_state.get_current_picker(prompt_bufnr)
---       local results = {}
---         action_utils.map_selections(prompt_bufnr, function(entry, index)
---         results[index] = entry.value
---       end)
---       return results
---     end
--- </pre>
---@param prompt_bufnr number: The prompt bufnr
---@param f function: Function to map onto selection of picker that takes (selection) as a viable argument
function utils.map_selections(prompt_bufnr, f)
  vim.validate{
    f = {f, "function"}
  }
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  for _, selection in ipairs(current_picker:get_multi_selection()) do
    f(selection)
  end
end

return utils
