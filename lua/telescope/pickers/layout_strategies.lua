---@tag telescope.layout

---@brief [[
---
--- Layout strategies are different functions to position telescope.
---
--- All layout strategies are functions with the following signature:
---
--- <pre>
---   function(picker, columns, lines)
---     -- Do some calculations here...
---     return {
---       preview = preview_configuration
---       results = results_configuration,
---       prompt = prompt_configuration,
---     }
---   end
---
---   Parameters: ~
---     - picker  : A Picker object. (docs coming soon)
---     - columns : number Columns in the vim window
---     - lines   : number Lines in the vim window
---
--- </pre>
---
--- TODO: I would like to make these link to `telescope.layout_strategies.*`,
--- but it's not yet possible.
---
--- Available layout strategies include:
---   - horizontal:
---     - See |layout_strategies.horizontal|
---
---   - vertical:
---     - See |layout_strategies.vertical|
---
---   - flex:
---     - See |layout_strategies.flex|
---
--- Available tweaks to the settings in layout defaults include
--- (can be applied to horizontal and vertical layouts):
---   - mirror (default is `false`):
---     - Flip the view of the current layout:
---       - If using horizontal: if `true`, swaps the location of the
---         results/prompt window and preview window
---       - If using vertical: if `true`, swaps the location of the results and
---         prompt windows
---
---   - width:
---     - How wide to make Telescope's layout window
---     - Resolvable: see |resolver.resolve_width()|
---
---   - height:
---     - How tall to make Telescope's layout window
---     - Resolvable: see |resolver.resolve_height()|
---
---   - scroll_speed:
---     - Change the scrolling speed of the previewer
---
--- The horizontal layout also has:
---   - preview_width:
---     - Change the width of Telescope's preview window
---     - Resolvable: see |resolver.resolve_width()| <br>
---         Note that percentages are measured relative to the size of the whole layout.
---
--- Similarly, the vertical layout has:
---   - preview_height:
---     - Change the height of Telescope's preview window
---     - Resolvable: see |resolver.resolve_height()| <br>
---         Note that percentages are measured relative to the size of the whole layout.
---@brief ]]

local resolve = require('telescope.config.resolve')

local get_default = require('telescope.utils').get_default

local p_window = require('telescope.pickers.window')


-- Check if there are any borders. Right now it's a little raw as
-- there are a few things that contribute to the border
local is_borderless = function(opts)
  return opts.window.border == false
end

local layout_strategies = {}

local function validate_layout_config(strategy, options, values)
  local result = {}
  -- Define a function to check that the keys in options match those
  -- in values or those in layout_list
  local function key_check(opts,vals,strat)
    for k, _ in pairs(opts) do
      if not vals[k] and not layout_strategies[k] then
        if strat == nil then
          error(string.format(
            "Unsupported layout_config key: %s\n%s",
            k,
            vim.inspect(vals)
          ))
        else
          error(string.format(
            "Unsupported layout_config key for the %s strategy: %s\n%s",
            strat,
            k,
            vim.inspect(vals)
          ))
        end
      end
    end
  end

  -- Check that options has the correct form for this strategy
  key_check(options,values)
  if options[strategy] ~= nil then
    if type(options[strategy]) ~= 'table' then
      error(string.format(
        'Unsupported layout_config for the %s strategy: %s\n%s\nShould be a table',
        strategy,
        vim.inspect(options[strategy])
      ))
    else
      key_check(options[strategy],values)
    end
  end

  -- Create the output table
  for k, _ in pairs(values) do
    -- Prioritise values that are specific to this strategy
    if options[strategy] ~= nil and options[strategy][k] ~= nil then
      result[k] = options[strategy][k]
    elseif options[k] ~= nil then
      result[k] = options[k]
    end
  end

  return result
end

--- Horizontal layout has two columns, one for the preview
--- and one for the prompt and results.
---
--- <pre>
--- ┌──────────────────────────────────────────────────┐
--- │                                                  │
--- │    ┌───────────────────┐┌───────────────────┐    │
--- │    │                   ││                   │    │
--- │    │                   ││                   │    │
--- │    │                   ││                   │    │
--- │    │      Results      ││                   │    │
--- │    │                   ││      Preview      │    │
--- │    │                   ││                   │    │
--- │    │                   ││                   │    │
--- │    └───────────────────┘│                   │    │
--- │    ┌───────────────────┐│                   │    │
--- │    │      Prompt       ││                   │    │
--- │    └───────────────────┘└───────────────────┘    │
--- │                                                  │
--- └──────────────────────────────────────────────────┘
--- </pre>
layout_strategies.horizontal = function(self, max_columns, max_lines)
  local layout_config = validate_layout_config('horizontal',self.layout_config or {}, {
    width = "How wide the picker is",
    height = "How tall the picker is",
    preview_width = "(Resolvable): Determine preview width",
    mirror = "Flip the location of the results/prompt and preview windows",
    scroll_speed = "The speed when scrolling through the previewer",
  })

  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  -- TODO: Test with 120 width terminal
  -- TODO: Test with self.width
  local width_opt = get_default(self.window.width,layout_config.width)
  local picker_width = resolve.resolve_width(width_opt)(self,max_columns,max_lines)
  local width_padding = math.floor((max_columns - picker_width)/2)

  local height_opt = get_default(self.window.height,layout_config.height)
  local picker_height = resolve.resolve_height(height_opt)(self,max_columns,max_lines)
  local height_padding = math.floor((max_lines - picker_height)/2)

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

  -- Default value is false, to use the normal horizontal layout
  if not layout_config.mirror then
    results.col = width_padding
    prompt.col = width_padding
    preview.col = results.col + results.width + 2
  else
    preview.col = width_padding
    prompt.col = preview.col + preview.width + 2
    results.col = preview.col + preview.width + 2
  end

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

--- Centered layout with a combined block of the prompt
--- and results aligned to the middle of the screen.
--- The preview window is then placed in the remaining space above.
--- Particularly useful for creating dropdown menus
--- (try using `theme=get_dropdown`).
---
--- <pre>
--- ┌──────────────────────────────────────────────────┐
--- │    ┌────────────────────────────────────────┐    │
--- │    |                 Preview                |    │
--- │    |                 Preview                |    │
--- │    └────────────────────────────────────────┘    │
--- │    ┌────────────────────────────────────────┐    │
--- │    |                 Prompt                 |    │
--- │    ├────────────────────────────────────────┤    │
--- │    |                 Result                 |    │
--- │    |                 Result                 |    │
--- │    └────────────────────────────────────────┘    │
--- │                                                  │
--- │                                                  │
--- │                                                  │
--- │                                                  │
--- └──────────────────────────────────────────────────┘
--- </pre>
layout_strategies.center = function(self, max_columns, max_lines)
  local layout_config = validate_layout_config('center',self.layout_config or {}, {
    width = "How wide the picker is",
    scroll_speed = "The speed when scrolling through the previewer",
  })
  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  -- This sets the width for the whole layout
  local width_opt = get_default(self.window.width,layout_config.width)
  local width = resolve.resolve_width(width_opt)(self, max_columns, max_lines)

  -- This sets the number of results displayed
  local res_height = resolve.resolve_height(self.window.results_height)(self, max_columns, max_lines)

  local max_results = (res_height > max_lines and max_lines or res_height)
  local max_width = (width > max_columns and max_columns or width)

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

  -- Align the prompt and results so halfway up the screen is
  -- in the middle of this combined block
  prompt.line = (max_lines / 2) - ((max_results + (bs * 2)) / 2)
  results.line = prompt.line + 1 + (bs)

  preview.line = 1
  preview.height = math.floor(prompt.line - (2 + bs))

  if not self.previewer or max_columns < self.preview_cutoff then
    preview.height = 0
  end

  results.col = math.ceil((max_columns / 2) - (width / 2) - bs)
  prompt.col = results.col
  preview.col = results.col

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end

--- Vertical layout stacks the items on top of each other.
--- Particularly useful with thinner windows.
---
--- <pre>
--- ┌──────────────────────────────────────────────────┐
--- │                                                  │
--- │    ┌────────────────────────────────────────┐    │
--- │    |                 Preview                |    │
--- │    |                 Preview                |    │
--- │    |                 Preview                |    │
--- │    └────────────────────────────────────────┘    │
--- │    ┌────────────────────────────────────────┐    │
--- │    |                 Result                 |    │
--- │    |                 Result                 |    │
--- │    └────────────────────────────────────────┘    │
--- │    ┌────────────────────────────────────────┐    │
--- │    |                 Prompt                 |    │
--- │    └────────────────────────────────────────┘    │
--- │                                                  │
--- └──────────────────────────────────────────────────┘
--- </pre>
layout_strategies.vertical = function(self, max_columns, max_lines)
  local layout_config = validate_layout_config('vertical',self.layout_config or {}, {
    width = "How many cells to pad the width",
    height = "How many cells to pad the height",
    preview_height = "(Resolvable): Determine preview height",
    mirror = "Flip the locations of the results and prompt windows",
    scroll_speed = "The speed when scrolling through the previewer",
  })

  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_opt = get_default(self.window.width,layout_config.width)
  local picker_width = resolve.resolve_width(width_opt)(self,max_columns,max_lines)
  local width_padding = math.floor((max_columns - picker_width)/2)

  local height_opt = get_default(self.window.height,layout_config.height)
  local picker_height = resolve.resolve_height(height_opt)(self,max_columns,max_lines)
  local height_padding = math.floor((max_lines - picker_height)/2)

  if not self.previewer then
    preview.width = 0
  else
    preview.width = picker_width
  end
  results.width = picker_width
  prompt.width = picker_width

  local preview_total = 0
  preview.height = 0
  if self.previewer then
    preview.height = resolve.resolve_height(
      layout_config.preview_height or 0.5
    )(self, max_columns, picker_height)

    preview_total = preview.height + 2
  end

  prompt.height = 1
  results.height = picker_height - preview_total - prompt.height - 2

  results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

  if self.previewer then
    if not layout_config.mirror then
      preview.line = height_padding
      results.line = preview.line + preview.height + 2
      prompt.line = results.line + results.height + 2
    else
      prompt.line = height_padding
      results.line = prompt.line + prompt.height + 2
      preview.line = results.line + results.height + 2
    end
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

--- Flex layout swaps between `horizontal` and `vertical` strategies based on the window width
---  -  Supports `vertical` or `horizontal` features
---
--- Uses:
---  - flip_columns
---  - flip_lines
layout_strategies.flex = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}

  local flip_columns = layout_config.flip_columns or 100
  local flip_lines = layout_config.flip_lines or 20

  if max_columns < flip_columns and max_lines > flip_lines then
    return layout_strategies.vertical(self, max_columns, max_lines)
  else
    return layout_strategies.horizontal(self, max_columns, max_lines)
  end
end

layout_strategies.current_buffer = function(self, _, _)
  local initial_options = p_window.get_initial_window_options(self)

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

layout_strategies.bottom_pane = function(self, max_columns, max_lines)
  local layout_config = validate_layout_config(
    "bottom_pane",
    self.layout_config or {},
    {
      height = "The height of the layout",
    }
  )

  local initial_options = p_window.get_initial_window_options(self)
  local results = initial_options.results
  local prompt = initial_options.prompt
  local preview = initial_options.preview

  local result_height = resolve.resolve_height(layout_config.height)(self,max_columns,max_lines) or 25

  local prompt_width = max_columns
  local col = 0

  local has_border = not not self.window.border
  if has_border then
    col = 1
    prompt_width = prompt_width - 2
  end

  local result_width
  if self.previewer then
    result_width = math.floor(prompt_width / 2)

    local base_col = result_width + 1
    if has_border then
      preview = vim.tbl_deep_extend("force", {
        col = base_col + 2,
        line = max_lines - result_height + 1,
        width = prompt_width - result_width - 2,
        height = result_height - 1,
      }, preview)
    else
      preview = vim.tbl_deep_extend("force", {
        col = base_col,
        line = max_lines - result_height,
        width = prompt_width - result_width,
        height = result_height,
      }, preview)
    end
  else
    preview = nil
    result_width = prompt_width
  end

  return {
    preview = preview,
    prompt = vim.tbl_deep_extend("force", prompt, {
      line = max_lines - result_height - 1,
      col = col,
      height = 1,
      width = prompt_width,
    }),
    results = vim.tbl_deep_extend("force", results, {
      line = max_lines - result_height,
      col = col,
      height = result_height,
      width = result_width,
    }),
  }
end

return layout_strategies
