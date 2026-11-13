local resolve = require("telescope.config.resolve")

local M = {}

function M.get_window_options(picker, max_columns, max_lines)
  local layout_strategy = picker.layout_strategy
  local getter = require("telescope.pickers.layout_strategies")[layout_strategy]
  ---@cast getter (fun(picker: Picker, max_columns: integer, max_lines: integer): table)?

  if not getter then
    error(string.format("'%s' is not a valid layout strategy", layout_strategy))
  end

  return getter(picker, max_columns, max_lines)
end

---@return { preview: telescope.pickers.WindowOptions, results: telescope.pickers.WindowOptions, prompt: telescope.pickers.WindowOptions }
function M.get_initial_window_options(picker)
  local popup_border = resolve.win_option(picker.window.border)
  local popup_borderchars = resolve.win_option(picker.window.borderchars)

  local preview = {
    title = picker.preview_title,
    border = popup_border.preview,
    borderchars = popup_borderchars.preview,
    enter = false,
    highlight = false,
  }
  ---@cast preview telescope.pickers.WindowOptions

  local results = {
    title = picker.results_title,
    border = popup_border.results,
    borderchars = popup_borderchars.results,
    enter = false,
  }
  ---@cast results telescope.pickers.WindowOptions

  local prompt = {
    title = picker.prompt_title,
    border = popup_border.prompt,
    borderchars = popup_borderchars.prompt,
    enter = true,
  }
  ---@cast prompt telescope.pickers.WindowOptions

  return {
    preview = preview,
    results = results,
    prompt = prompt,
  }
end

return M
