
local layout_strategies = {}

layout_strategies.horizontal = function(self, max_columns, max_lines, prompt_title)
  local initial_options = self:_get_initial_window_options(prompt_title)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  -- TODO: Test with 120 width terminal
  -- TODO: Test with self.width.

  local width_padding = 10
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
  results.minheight = results.height
  prompt.height = 1
  prompt.minheight = prompt.height

  if self.previewer then
    preview.height = results.height + prompt.height + 2
    preview.minheight = preview.height
  else
    preview.height = 0
  end

  results.col = width_padding
  prompt.col = width_padding
  preview.col = results.col + results.width + 2

  -- TODO: Center this in the page a bit better.
  local height_padding = math.max(math.floor(0.95 * max_lines), 2)
  results.line = max_lines - height_padding
  prompt.line = results.line + results.height + 2
  preview.line = results.line

  return {
    preview = preview.width > 0 and preview,
    results = results,
    prompt = prompt,
  }
end

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
  results.minheight = 10
  prompt.height = 1
  prompt.minheight = 1

  -- The last 2 * 2 is for the extra borders
  if self.previewer then
    preview.height = max_lines - results.height - prompt.height - 2 * 2 - height_padding * 2
    preview.minheight = preview.height
  else
    results.height = max_lines - prompt.height - 2 - height_padding * 2
    results.minheight = results.height
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

-- TODO: Add "flex"
-- If you don't have enough width, use the height one
-- etc.

return layout_strategies
