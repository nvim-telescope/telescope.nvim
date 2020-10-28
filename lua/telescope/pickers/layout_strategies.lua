--[[

Layout strategies are different functions to position telescope.

horizontal:
- Supports `prompt_position`, `preview_cutoff`

vertical:

flex: Swap between `horizontal` and `vertical` strategies based on the window width
- Supports `vertical` or `horizontal` features

dropdown:


Layout strategies are callback functions

-- @param self: Picker
-- @param columns: number Columns in the vim window
-- @param lines: number Lines in the vim window

function(self, columns, lines)
end

--]]

local config = require('telescope.config')
local resolve = require("telescope.config.resolve")

-- Check if there are any borders. Right now it's a little raw as
-- there are a few things that contribute to the border
local is_borderless = function(opts)
  return opts.window.border == false
end


local function validate_layout_config(options, values)
  for k, _ in pairs(options) do
    if not values[k] then
      error(string.format(
        "Unsupported layout_config key: %s\n%s",
        k,
        vim.inspect(values)
      ))
    end
  end

  return options
end

local layout_strategies = {}

--[[
   +-----------------+---------------------+
   |                 |                     |
   |     Results     |                     |
   |                 |       Preview       |
   |                 |                     |
   +-----------------|                     |
   |     Prompt      |                     |
   +-----------------+---------------------+
--]]
layout_strategies.horizontal = function(self, max_columns, max_lines)
  local layout_config = validate_layout_config(self.layout_config or {}, {
    width_padding = "How many cells to pad the width",
    height_padding = "How many cells to pad the height",
    preview_width = "(Resolvable): Determine preview width",
  })

  local initial_options = self:_get_initial_window_options()
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  -- TODO: Test with 120 width terminal
  -- TODO: Test with self.width
  local width_padding = resolve.resolve_width(layout_config.width_padding or function(_, cols)
    if cols < self.preview_cutoff then
      return 2
    elseif cols < 150 then
      return 5
    else
      return 10
    end
  end)(self, max_columns, max_lines)
  local picker_width = max_columns - 2 * width_padding

  local height_padding = resolve.resolve_height(layout_config.height_padding or function(_, _, lines)
    if lines < 40 then
      return 4
    else
      return math.floor(0.1 * lines)
    end
  end)(self, max_columns, max_lines)
  local picker_height = max_lines - 2 * height_padding

  if self.previewer then
    preview.width = resolve.resolve_width(layout_config.preview_width or function(_, cols)
      if not self.previewer or cols < self.preview_cutoff then
        return 0
      elseif cols < 150 then
        return math.floor(cols * 0.4)
      elseif cols < 200 then
        return 80
      else
        return 120
      end
    end)(self, picker_width, max_lines)
  else
    preview.width = 0
  end

  results.width = picker_width - preview.width
  prompt.width = picker_width - preview.width

  prompt.height = 1
  results.height = picker_height - prompt.height - 2

  if self.previewer then
    preview.height = picker_height
  else
    preview.height = 0
  end

  results.col = width_padding
  prompt.col = width_padding
  preview.col = results.col + results.width + 2

  preview.line = height_padding
  if self.window.prompt_position == "top" then
    prompt.line = height_padding
    results.line = prompt.line + prompt.height + 2
  elseif self.window.prompt_position == "bottom" then
    results.line = height_padding
    prompt.line = results.line + results.height + 2
  else
    error("Unknown prompt_position: " .. self.window.prompt_position)
  end

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
}
end

--[[
    +--------------+
    |    Preview   |
    +--------------+
    |    Prompt    |
    +--------------+
    |    Result    |
    |    Result    |
    |    Result    |
    +--------------+


--]]
layout_strategies.center = function(self, columns, lines)
  local initial_options = self:_get_initial_window_options()
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  -- This sets the height/width for the whole layout
  local height = resolve.resolve_height(self.window.results_height)(self, columns, lines)
  local width = resolve.resolve_width(self.window.width)(self, columns, lines)

  local max_results = (height > lines and lines or height)
  local max_width = (width > columns and columns or width)

  prompt.height = 1
  results.height = max_results

  prompt.width = max_width
  results.width = max_width
  preview.width = max_width

  -- border size
  local bs = 1
  if is_borderless(self) then
    bs = 0
  end

  prompt.line = (lines / 2) - ((max_results + (bs * 2)) / 2)
  results.line = prompt.line + 1 + (bs)

  preview.line = 1
  preview.height = math.floor(prompt.line - (2 + bs))

  if not self.previewer or columns < self.preview_cutoff then
    preview.height = 0
  end

  results.col = math.ceil((columns / 2) - (width / 2) - bs)
  prompt.col = results.col
  preview.col = results.col

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end

--[[
    +-----------------+
    |    Previewer    |
    |    Previewer    |
    |    Previewer    |
    +-----------------+
    |     Result      |
    |     Result      |
    |     Result      |
    +-----------------+
    |     Prompt      |
    +-----------------+
--]]
layout_strategies.vertical = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}
  local initial_options = self:_get_initial_window_options()

  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = resolve.resolve_width(
    layout_config.width_padding or math.ceil((1 - self.window.width) * 0.5 * max_columns)
  )(self, max_columns, max_lines)

  local width = max_columns - width_padding * 2
  if not self.previewer then
    preview.width = 0
  else
    preview.width = width
  end
  results.width = width
  prompt.width = width

  -- Height
  local height_padding = math.max(
    1, 
    resolve.resolve_height(layout_config.height_padding or 3)(self, max_columns, max_lines)
  )
  local picker_height = max_lines - 2 * height_padding

  local preview_total = 0
  preview.height = 0
  if self.previewer then
    preview.height = resolve.resolve_height(
      layout_config.preview_height or (max_lines - 15)
    )(self, max_columns, picker_height)

    preview_total = preview.height + 2
  end

  prompt.height = 1
  results.height = picker_height - preview_total - prompt.height - 2

  results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

  if self.previewer then
    preview.line = height_padding
    results.line = preview.line + preview.height + 2
    prompt.line = results.line + results.height + 2
  else
    results.line = height_padding
    prompt.line = results.line + results.height + 2
  end

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end

-- Uses:
--  flip_columns
--  flip_lines
layout_strategies.flex = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}

  local flip_columns = layout_config.flip_columns or 100
  local flip_lines = layout_config.flip_lines or 20

  if max_columns < flip_columns and max_lines > flip_lines then
    -- TODO: This feels a bit like a hack.... cause you wouldn't be able to pass this to flex easily.
    self.layout_config = (config.values.layout_defaults or {})['vertical']
    return layout_strategies.vertical(self, max_columns, max_lines)
  else
    self.layout_config = (config.values.layout_defaults or {})['horizontal']
    return layout_strategies.horizontal(self, max_columns, max_lines)
  end
end

layout_strategies.current_buffer = function(self, _, _)
  local initial_options = self:_get_initial_window_options()

  local window_width = vim.api.nvim_win_get_width(0)
  local window_height = vim.api.nvim_win_get_height(0)

  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = 2
  local width = window_width - width_padding * 2
  if not self.previewer then
    preview.width = 0
  else
    preview.width = width
  end
  results.width = width
  prompt.width = width

  -- Height
  local height_padding = 3

  results.height = 10
  prompt.height = 1

  -- The last 2 * 2 is for the extra borders
  if self.previewer then
    preview.height = window_height - results.height - prompt.height - 2 * 2 - height_padding * 2
  else
    results.height = window_height - prompt.height - 2 - height_padding * 2
  end


  local win_position = vim.api.nvim_win_get_position(0)

  local line = win_position[1]
  if self.previewer then
    preview.line = height_padding + line
    results.line = preview.line + preview.height + 2
    prompt.line = results.line + results.height + 2
  else
    results.line = height_padding + line
    prompt.line = results.line + results.height + 2
  end

  local col = win_position[2] + width_padding
  preview.col, results.col, prompt.col = col, col, col

  return {
    preview = preview.width > 0 and preview,
    results = results,
    prompt = prompt,
  }
end

return layout_strategies
