local resolve = require "telescope.config.resolve"

local p_window = {}

function p_window.get_window_options(picker, max_columns, max_lines)
  local layout_strategy = picker.layout_strategy
  local getter = require("telescope.pickers.layout_strategies")[layout_strategy]

  if not getter then
    error(string.format("'%s' is not a valid layout strategy", layout_strategy))
  end

  return getter(picker, max_columns, max_lines)
end

function p_window._set_additional_fields(popup_opts)
  -- `popup.nvim` massaging so people don't have to remember minheight shenanigans
  popup_opts.results.minheight = popup_opts.results.height
  popup_opts.results.highlight = "TelescopeResultsNormal"
  popup_opts.results.borderhighlight = "TelescopeResultsBorder"
  popup_opts.results.titlehighlight = "TelescopeResultsTitle"
  popup_opts.prompt.minheight = popup_opts.prompt.height
  popup_opts.prompt.highlight = "TelescopePromptNormal"
  popup_opts.prompt.borderhighlight = "TelescopePromptBorder"
  popup_opts.prompt.titlehighlight = "TelescopePromptTitle"
  if popup_opts.preview then
    popup_opts.preview.minheight = popup_opts.preview.height
    popup_opts.preview.highlight = "TelescopePreviewNormal"
    popup_opts.preview.borderhighlight = "TelescopePreviewBorder"
    popup_opts.preview.titlehighlight = "TelescopePreviewTitle"
  end

  return popup_opts
end

function p_window.get_initial_window_options(picker)
  local popup_border = resolve.win_option(picker.window.border)
  local popup_borderchars = resolve.win_option(picker.window.borderchars)

  local preview = {
    title = picker.preview_title,
    border = popup_border.preview,
    borderchars = popup_borderchars.preview,
    enter = false,
    highlight = false,
  }

  local results = {
    title = picker.results_title,
    border = popup_border.results,
    borderchars = popup_borderchars.results,
    enter = false,
  }

  local prompt = {
    title = picker.prompt_title,
    border = popup_border.prompt,
    borderchars = popup_borderchars.prompt,
    enter = true,
  }

  return {
    preview = preview,
    results = results,
    prompt = prompt,
  }
end

return p_window
