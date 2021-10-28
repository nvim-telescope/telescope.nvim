---@tag telescope.actions.layout

---@brief [[
--- The layout actions are actions to be used to change the layout of a picker.
---@brief ]]

local action_state = require "telescope.actions.state"
local layout_strats = require "telescope.pickers.layout_strategies"

local action_layout = {}

--- Toggles the `prompt_position` option between "top" and "bottom".
--- Checks if `prompt_position` is an option for the current layout.
---
--- This action is not mapped by default.
---@param prompt_bufnr number: The prompt bufnr
action_layout.toggle_prompt_position = function(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  if layout_strats._configurations[picker.layout_strategy].prompt_position then
    if picker.layout_config.prompt_position == "top" then
      picker.layout_config.prompt_position = "bottom"
      picker.layout_config[picker.layout_strategy].prompt_position = "bottom"
    else
      picker.layout_config.prompt_position = "top"
      picker.layout_config[picker.layout_strategy].prompt_position = "top"
    end
    picker:full_layout_update()
  end
end

--- Toggles the `mirror` option between `true` and `false`.
--- Checks if `mirror` is an option for the current layout.
---
--- This action is not mapped by default.
---@param prompt_bufnr number: The prompt bufnr
action_layout.toggle_mirror = function(prompt_bufnr)
  local picker = action_state.get_current_picker(prompt_bufnr)
  if layout_strats._configurations[picker.layout_strategy].mirror then
    picker.layout_config.mirror = not picker.layout_config.mirror
    picker.layout_config[picker.layout_strategy].mirror = not picker.layout_config.mirror
    picker:full_layout_update()
  end
end

-- Helper function for `cycle_layout_next` and `cycle_layout_prev`.
local get_cycle_layout = function(dir)
  return function(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    if picker.__layout_index then
      picker.__layout_index = ((picker.__layout_index + dir - 1) % #picker.__cycle_layout_list) + 1
    else
      picker.__layout_index = 1
    end
    local new_layout = picker.__cycle_layout_list[picker.__layout_index]
    if type(new_layout) == "string" then
      picker.layout_strategy = new_layout
      picker.layout_config = nil
      picker.previewer = picker.all_previewers[1]
    elseif type(new_layout) == "table" then
      picker.layout_strategy = new_layout.layout_strategy
      picker.layout_config = new_layout.layout_config
      picker.previewer = (new_layout.previewer == nil and picker.all_previewers[picker.current_previewer_index])
        or new_layout.previewer
    else
      error("Not a valid layout setup: " .. vim.inspect(new_layout) .. "\nShould be a string or a table")
    end

    picker:full_layout_update()
  end
end

--- Cycles to the next layout in `cycle_layout_list`.
---
--- This action is not mapped by default.
---@param prompt_bufnr number: The prompt bufnr
action_layout.cycle_layout_next = get_cycle_layout(1)

--- Cycles to the previous layout in `cycle_layout_list`.
---
--- This action is not mapped by default.
---@param prompt_bufnr number: The prompt bufnr
action_layout.cycle_layout_prev = get_cycle_layout(-1)

return action_layout
