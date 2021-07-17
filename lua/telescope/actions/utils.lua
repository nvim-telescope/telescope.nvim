---@tag telescope.actions.utils

---@brief [[
--- Utilities to wrap functions around picker selections and entries.
---
--- Generally used from within other |telescope.actions|
---@brief ]]

local action_state = require "telescope.actions.state"
local global_state = require "telescope.state"

local utils = require "telescope.utils"
local action_utils = {}

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
function action_utils._map_entries(prompt_bufnr, f)
  vim.validate {
    f = { f, "function" },
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

function action_utils.map_entries(f)
  return function(prompt_bufnr)
    action_utils._map_entries(prompt_bufnr, f)
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
function action_utils._map_selections(prompt_bufnr, f)
  vim.validate {
    f = { f, "function" },
  }
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  for _, selection in ipairs(current_picker:get_multi_selection()) do
    f(selection)
  end
end

function action_utils.map_selections(f)
  return function(prompt_bufnr)
    action_utils._map_selections(prompt_bufnr, f)
  end
end

-- TODO more control flow
function action_utils._with_selections(prompt_bufnr, action)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  for index, selection in ipairs(current_picker:get_multi_selection()) do
    global_state.set_global_key("set_entry", selection)
    action(prompt_bufnr)
  end
end

function action_utils.with_selections(action)
  return function(prompt_bufnr)
    action_utils._with_selections(prompt_bufnr, action)
  end
end

function action_utils.with_selection(action, selection_index)
  selection_index = vim.F.if_nil(selection_index, 1)
  return function(prompt_bufnr)
    local current_picker = action_state.get_current_picker(prompt_bufnr)
    local selections = current_picker:get_multi_selection()
    global_state.set_global_key("set_entry", selections[selection_index])
    action(prompt_bufnr)
  end
end

function action_utils.round_robin(actions)
  local num_actions = #actions
  local cycle = function(i, n)
    local result = i % n
    return result == 0 and n or result
  end
  return function(prompt_bufnr)
    -- level 3 is the calling function
    local variables = utils.locals(3)
    if variables.index == nil then
      print("No index found! Cannot cycle through, attempting to abort safely...")
      return 
    end
    actions[cycle(variables.index, num_actions)](prompt_bufnr)
  end
end

function action_utils._with_entries(prompt_bufnr, action)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local index = 1
  for entry in current_picker.manager:iter() do
    global_state.set_global_key("set_entry", entry)
    action(prompt_bufnr)
    index = index + 1
  end
end

function action_utils.with_entries(action)
  return function(prompt_bufnr)
    action_utils._with_entries(prompt_bufnr, action)
  end
end

return action_utils
