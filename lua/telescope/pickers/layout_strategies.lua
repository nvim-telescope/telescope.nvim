
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
    prompt = prompt,
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

-- TODO: Add "flex"
-- If you don't have enough width, use the height one
-- etc.

return layout_strategies
