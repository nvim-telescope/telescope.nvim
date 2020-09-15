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
-- @param prompt_title: string
function(self, columns, lines, prompt_title)
end

--]]

local layout_strategies = {}
local log = require("telescope.log")
local resolve = require("telescope.config.resolve")
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
layout_strategies.horizontal = function(self, max_columns, max_lines, prompt_title)
  local initial_options = self:_get_initial_window_options(prompt_title)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  -- TODO: Test with 120 width terminal
  -- TODO: Test with self.width
  local width_padding = 10

  -- TODO: Determine config settings.
  if false and self.window.horizontal_config and self.window.horizontal_config.get_preview_width then
    preview.width = self.window.horizontal_config.get_preview_width(max_columns, max_lines)
  else
    if not self.previewer or max_columns < self.preview_cutoff then
      width_padding = 2
      preview.width = 0
    elseif max_columns < 150 then
      width_padding = 5
      preview.width = math.floor(max_columns * 0.4)
    elseif max_columns < 200 then
      preview.width = 80
    else
      preview.width = 120
    end
  end

  local other_width = max_columns - preview.width - (2 * width_padding)

  results.width = other_width
  prompt.width = other_width

  local base_height
  if max_lines < 40 then
    base_height = math.min(math.floor(max_lines * 0.8), max_lines - 8)
  else
    base_height = math.floor(max_lines * 0.8)
  end
  results.height = base_height
  prompt.height = 1

  if self.previewer then
    preview.height = results.height + prompt.height + 2
  else
    preview.height = 0
  end

  results.col = width_padding
  prompt.col = width_padding
  preview.col = results.col + results.width + 2

  -- TODO: Center this in the page a bit better.
  local height_padding = math.max(math.floor(0.95 * max_lines), 2)

  if self.window.prompt_position == "top" then
    prompt.line = max_lines - height_padding
    results.line = prompt.line + 3
    preview.line = prompt.line
  elseif self.window.prompt_position == "bottom" then
    results.line = max_lines - height_padding
    prompt.line = results.line + results.height + 2
    preview.line = results.line
  else
    error("Unknown prompt_position: " .. self.window.prompt_position)
  end

  return {
    preview = preview.width > 0 and preview,
    results = results,
    prompt = prompt
}
end

--[[
    +-----------------+
    |     Prompt      |
    +-----------------+
    |     Result      |
    |     Result      |
    |     Result      |
    +-----------------+
--]]

-- Check if there are any borders. Right now it's a little raw as
-- there are a few things that contribute to the border
local is_borderless = function(opts)
  if opts.window.border == false then return true end
end

layout_strategies.center = function(self, columns, lines, prompt_title)
  local initial_options = self:_get_initial_window_options(prompt_title)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local max_results = self.max_results or 15
  local width = self.width or 70

  local max_width = (width > columns and columns or width)

  prompt.height = 1
  results.height = max_results

  prompt.width = max_width
  results.width = max_width
  preview.width = max_width

  local bs = 1 -- border size

  if is_borderless(self) then bs = 0 end

  prompt.line = (lines / 2) - ((max_results + (bs * 2)) / 2)
  results.line = prompt.line + prompt.height + (bs * 2)

  preview.line = 1
  preview.height = math.floor(prompt.line - 2)

  if not self.previewer or columns < self.preview_cutoff then
    preview.height = 0
  end

  -- Get left column, after centering, appling the width, and the border size
  results.col = (columns / 2) - (width / 2) + (bs * 2)
  prompt.col = results.col
  preview.col = results.col

  return {
    preview = self.previewer and preview,
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
layout_strategies.vertical = function(self, max_columns, max_lines, prompt_title)
  local initial_options = self:_get_initial_window_options(prompt_title)

  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = math.ceil((1 - self.window.width) * 0.5 * max_columns)
  local width = max_columns - width_padding * 2
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
    preview.height = max_lines - results.height - prompt.height - 2 * 2 - height_padding * 2
  else
    results.height = max_lines - prompt.height - 2 - height_padding * 2
  end

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
    preview = preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end

layout_strategies.flex = function(self, max_columns, max_lines, prompt_title)
  -- TODO: Make a config option for this that makes sense.
  if max_columns < 100 and max_lines > 20 then
    return layout_strategies.vertical(self, max_columns, max_lines, prompt_title)
  else
    return layout_strategies.horizontal(self, max_columns, max_lines, prompt_title)
  end
end

layout_strategies.current_buffer = function(self, _, _, prompt_title)
  local initial_options = self:_get_initial_window_options(prompt_title)

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

-- TODO: Add "flex"
-- If you don't have enough width, use the height one
-- etc.

return layout_strategies
