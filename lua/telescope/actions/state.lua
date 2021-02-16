local global_state = require('telescope.state')

local action_state = {}

--- Get the current entry
function action_state.get_selected_entry()
  return global_state.get_global_key('selected_entry')
end

--- Gets the current line
function action_state.get_current_line()
  return global_state.get_global_key('current_line')
end

--- Gets the current picker
function action_state.get_current_picker(prompt_bufnr)
  return global_state.get_status(prompt_bufnr).picker
end

local select_to_edit_map = {
  default = "edit",
  horizontal = "new",
  vertical = "vnew",
  tab = "tabedit",
}
function action_state.select_key_to_edit_key(type)
  return select_to_edit_map[type]
end

return action_state
