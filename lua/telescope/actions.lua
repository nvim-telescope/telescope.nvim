-- Actions functions that are useful for people creating their own mappings.

local state = require('telescope.state')

local actions = {}


--- Get the current picker object for the prompt
function actions.get_current_picker(prompt_bufnr)
  return state.get_status(prompt_bufnr).picker
end

--- Move the current selection of a picker {change} rows.
--- Handles not overflowing / underflowing the list.
function actions.shift_current_selection(prompt_bufnr, change)
  actions.get_current_picker(prompt_bufnr):move_selection(change)
end

--- Get the current entry
function actions.get_selected_entry(prompt_bufnr)
  return actions.get_current_picker(prompt_bufnr):get_selection()
end


return actions
