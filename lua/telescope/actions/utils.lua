---@tag telescope.actions.utils

---@brief [[
--- Utilities to wrap actions and functions around picker selections and entries.
--- Generally used with other |telescope.actions| or custom functions that lever entries or selections.<br>
--- The functions without the `_` prefix are intended to be mapped at setup, whereas `functions` with the `_` prefix
--- are intended to be used in custom actions. Refer to the respective function documentation for examples.<br>
--- The functions that take `action(s)` as input typically are |telescope.actions| that lever the
--- `action_state.selected_entry`. In particular, `action_utils.with_{entries, selection, selections}`
--- intermittently override the `selected_entry` to perform the |telescope.actions| accordingly.
--- More generally, `actions` are functions are akin to the below example
--- <pre>
---   local action_state = require "telescope.actions.state"
---   function(prompt_bufnr)
---     local entry = action_state.get_selected_entry()
---     -- lever entry for function
---     ...
---   end
--- </pre>
---@brief ]]

local action_state = require "telescope.actions.state"
local global_state = require "telescope.state"

local action_utils = {}

--- Apply `f` to the entries of the current picker and prompt.
--- - `f` takes (entry, index, row) as arguments.
--- - Notes:
---   - Mapped entries may include results not visible in the results popup.
---   - Indices are 1-indexed, whereas rows are 0-indexed.
--- - Warning: `map_entries` has no return value.
---   - The below example showcase how to collect results.
--- <pre>
--- Example Usage: collect entries in key-value table
---   local action_state = require "telescope.actions.state"
---   local action_utils = require "telescope.actions.utils"
---   require("telescope").setup {
---     defaults = {
---       mappings = {
---         i = {
---           -- with `action_utils._map_entries`
---           ['<C-e>'] = function(prompt_bufnr)
---               local results = {}
---               action_utils._with_entries(prompt_bufnr, function(entry, entry_index)
---               results[entry_index] = entry
---               return results
---             end)
---           end,
---           -- with `action_utils.map_entries`
---           ['<C-e>'] = action_utils.with_entries(function(entry, entry_index)
---               results[entry_index] = entry
---               return results
---             end)
---         },
---       },
---     },
---   }
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

--- Apply `f` to the entries of the current picker and prompt.
--- See |action_utils._map_entries| for further information.
--- - `f` takes (entry, index, row) as arguments.
function action_utils.map_entries(f)
  return function(prompt_bufnr)
    action_utils._map_entries(prompt_bufnr, f)
  end
end

--- Apply `f` to the multi selections of the current picker and return a table of mapped selections.
--- - `f` takes (selection, selection_index) as arguments
--- - Notes:
---   - Mapped selections may include results not visible in the results popup.
---   - Selected entries are returned in order of their selection.
--- - Warning: `map_selections` has no return value.
---   - The below example showcases how to collect results
--- <pre>
--- Example Usage: collect selections in key-value table
---   local actions = require "telescope.actions"
---   local action_utils = require "telescope.actions.utils"
---   require("telescope").setup {
---     defaults = {
---       mappings = {
---         i = {
---         -- Collect selections
---           -- with `action_utils._map_selections`
---           ['<C-m>'] = function(prompt_bufnr)
---               local results = {}
---               action_utils._map_selections(prompt_bufnr, function(selection, selection_index)
---               results[selection_index] = selection
---               return results
---               end),
---             end
---           -- with `action_utils.map_selections`
---           ['<C-m>'] = action_utils.with_selections(function(selection, selection_index)
---               results[selection_index] = selection
---               return results
---             end),
---         },
---       },
---     },
---   }
--- </pre>
---@param prompt_bufnr number: The prompt bufnr
---@param f function: Function to map onto selection of picker that takes (selection, selection_index) as arguments
function action_utils._map_selections(prompt_bufnr, f)
  vim.validate {
    f = { f, "function" },
  }
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  for selection_index, selection in ipairs(current_picker:get_multi_selection()) do
    f(selection, selection_index)
  end
end

--- Apply `f` to the multi selections of the current picker and return a table of mapped selections.
--- See |action_utils._map_selections| for further information.
--- - `f` takes (selection, selection_index) as arguments
---@param f function: Function to map onto selection of picker that takes (selection, selection_index) as arguments
function action_utils.map_selections(f)
  return function(prompt_bufnr)
    action_utils._map_selections(prompt_bufnr, f)
  end
end

--- Run an `action` from |telescope.actions| on entries of the current picker and prompt.
--- - Notes:
---   - Mapped entries may include results not visible in the results popup.
---   - See |telescope.action.utils| for information on what functions constitute `actions`.
--- <pre>
--- Example Usage: git_staging_toggle
---   local actions = require "telescope.actions"
---   local action_utils = require "telescope.actions.utils"
---   require("telescope").setup {
---     defaults = {
---       pickers = {
---         git_status = {
---           mappings = {
---             i = {
---             -- Open selections vertically
---               -- with `action_utils._with_entries`
---               ['<S-Tab>'] = function(prompt_bufnr)
---                 action_utils.with_entries(prompt_bufnr, actions.git_staging_toggle)
---                 end,
---               -- with `action_utils.with_entries`
---               ['<S-Tab>'] = action_utils.with_entries(actions.git_staging_toggle)
---             },
---           },
---         },
---       },
---     }
---   }
--- </pre>
---@param f function: apply action onto all results
function action_utils._with_entries(prompt_bufnr, action)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local index = 1
  for entry in current_picker.manager:iter() do
    global_state.set_global_key("set_entry", entry)
    action(prompt_bufnr)
    index = index + 1
  end
end

--- Run an `action` from |telescope.actions| on the entries of the current picker and prompt.
--- - Note: see |action_utils._with_entries| for further information.
---@param f function: apply action onto all results
function action_utils.with_entries(action)
  return function(prompt_bufnr)
    action_utils._with_entries(prompt_bufnr, action)
  end
end

--- Run an `action` from |telescope.actions| on the multi selection.
--- - Note: see |telescope.action.utils| for information on what functions constitute `actions`.
--- <pre>
--- Example Usage: open selections vertically
---   local actions = require "telescope.actions"
---   local action_utils = require "telescope.actions.utils"
---   require("telescope").setup {
---     defaults = {
---       mappings = {
---         i = {
---         -- Open selections vertically
---           -- with `action_utils._with_selections`
---           ['<C-v><C-v>'] = function(prompt_bufnr)
---             action_utils.with_selections(prompt_bufnr, actions.select_vertical)
---             end,
---           -- with `action_utils.with_selections`
---           ['<C-v><C-v>'] = action_utils.with_selections(actions.select_vertical)
---         },
---       },
---     },
---   }
--- </pre>
---@param prompt_bufnr number: The prompt bufnr
---@param f function: apply action onto entries of multi selection
function action_utils._with_selections(prompt_bufnr, action)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  for _, selection in ipairs(current_picker:get_multi_selection()) do
    global_state.set_global_key("set_entry", selection)
    action(prompt_bufnr)
  end
end

--- Run an `action` from |telescope.actions| on the multi selection.
--- - Note: see |telescope.action.utils| for specification on what functions constitute `actions`.
---@param f function: apply action onto entries of multi selection
function action_utils.with_selections(action)
  return function(prompt_bufnr)
    action_utils._with_selections(prompt_bufnr, action)
  end
end

-- TODO: docs & mapping variant
function action_utils._with_selection(prompt_bufnr, action, selection_index)
  selection_index = vim.F.if_nil(selection_index, 1)
  local current_picker = action_state.get_current_picker(prompt_bufnr)
  local selections = current_picker:get_multi_selection()
  global_state.set_global_key("set_entry", selections[selection_index])
  action(prompt_bufnr)
end

function action_utils.with_selection(action, selection_index)
  return function(prompt_bufnr)
    action_utils._with_selection(prompt_bufnr, action, selection_index)
  end
end

--- Apply `actions` to multi selections or entries in cycle, on entry-after-entry basis.
--- Commonly used in combination with `action_utils.with_{selections, entries}`.
--- <pre>
--- Example Usage: open selections alternatingly vertically and horizontally
---   local actions = require "telescope.actions"
---   local action_utils = require "telescope.actions.utils"
---   require("telescope").setup {
---     defaults = {
---       mappings = {
---         i = {
---           ['<C-b>'] = action_utils.with_selections(
---                         action_utils.cycle({actions.select_vertical, actions.select_horizontal})
---         },
---       },
---     },
---   }
--- </pre>
---@param actions table: table of actions to apply iteratively
function action_utils.cycle(actions)
  local num_actions = #actions
  local index = 1
  local cycle = function(i, n)
    local result = i % n
    return result == 0 and n or result
  end
  return function(prompt_bufnr)
    actions[cycle(index, num_actions)](prompt_bufnr)
    index = index + 1
  end
end

return action_utils
