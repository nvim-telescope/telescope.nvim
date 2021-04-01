local p_layouts = require('telescope.pickers.layout_strategies')

local p_window = {}

function p_window.get_window_options(picker, max_columns, max_lines)
  local layout_strategy = picker.layout_strategy
  local getter = p_layouts[layout_strategy]

  if not getter then
    error("Not a valid layout strategy: " .. layout_strategy)
  end

  return getter(picker, max_columns, max_lines)
end


return p_window
