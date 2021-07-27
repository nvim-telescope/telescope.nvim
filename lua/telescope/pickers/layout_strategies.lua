---@tag telescope.layout

---@brief [[
---
--- Layout strategies are different functions to position telescope.
---
--- All layout strategies are functions with the following signature:
---
--- <pre>
---   function(picker, columns, lines, layout_config)
---     -- Do some calculations here...
---     return {
---       preview = preview_configuration
---       results = results_configuration,
---       prompt = prompt_configuration,
---     }
---   end
---
---   Parameters: ~
---     - picker        : A Picker object. (docs coming soon)
---     - columns       : (number) Columns in the vim window
---     - lines         : (number) Lines in the vim window
---     - layout_config : (table) The configuration values specific to the picker.
---
--- </pre>
---
--- This means you can create your own layout strategy if you want! Just be aware
--- for now that we may change some APIs or interfaces, so they may break if you create
--- your own.
---
--- A good method for creating your own would be to copy one of the strategies that most
--- resembles what you want from "./lua/telescope/pickers/layout_strategies.lua" in the
--- telescope repo.
---
---@brief ]]

local resolve = require "telescope.config.resolve"
local p_window = require "telescope.pickers.window"
local if_nil = vim.F.if_nil

local get_border_size = function(opts)
  if opts.window.border == false then
    return 0
  end

  return 1
end

local calc_tabline = function(max_lines)
  local tbln = (vim.o.showtabline == 2) or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
  if tbln then
    max_lines = max_lines - 1
  end
  return max_lines, tbln
end

local layout_strategies = {}
layout_strategies._configurations = {}

--@param strategy_config table: table with keys for each option for a strategy
--@return table: table with keys for each option (for this strategy) and with keys for each layout_strategy
local get_valid_configuration_keys = function(strategy_config)
  local valid_configuration_keys = {
    -- TEMP: There are a few keys we should say are valid to start with.
    preview_cutoff = true,
    prompt_position = true,
  }

  for key in pairs(strategy_config) do
    valid_configuration_keys[key] = true
  end

  for name in pairs(layout_strategies) do
    valid_configuration_keys[name] = true
  end

  return valid_configuration_keys
end

--@param strategy_name string: the name of the layout_strategy we are validating for
--@param configuration table: table with keys for each option available
--@param values table: table containing all of the non-default options we want to set
--@param default_layout_config table: table with the default values to configure layouts
--@return table: table containing the combined options (defaults and non-defaults)
local function validate_layout_config(strategy_name, configuration, values, default_layout_config)
  assert(strategy_name, "It is required to have a strategy name for validation.")
  local valid_configuration_keys = get_valid_configuration_keys(configuration)

  -- If no default_layout_config provided, check Telescope's config values
  default_layout_config = if_nil(default_layout_config, require("telescope.config").values.layout_config)

  local result = {}
  local get_value = function(k)
    -- skip "private" items
    if string.sub(k, 1, 1) == "_" then
      return
    end

    local val
    -- Prioritise options that are specific to this strategy
    if values[strategy_name] ~= nil and values[strategy_name][k] ~= nil then
      val = values[strategy_name][k]
    end

    -- Handle nested layout config values
    if layout_strategies[k] and strategy_name ~= k and type(val) == "table" then
      val = vim.tbl_deep_extend("force", default_layout_config[k], val)
    end

    if val == nil and values[k] ~= nil then
      val = values[k]
    end

    if val == nil then
      if default_layout_config[strategy_name] ~= nil and default_layout_config[strategy_name][k] ~= nil then
        val = default_layout_config[strategy_name][k]
      else
        val = default_layout_config[k]
      end
    end

    return val
  end

  -- Always set the values passed first.
  for k in pairs(values) do
    if not valid_configuration_keys[k] then
      -- TODO: At some point we'll move to error here,
      --    but it's a bit annoying to just straight up crash everyone's stuff.
      vim.api.nvim_err_writeln(
        string.format(
          "Unsupported layout_config key for the %s strategy: %s\n%s",
          strategy_name,
          k,
          vim.inspect(values)
        )
      )
    end

    result[k] = get_value(k)
  end

  -- And then set other valid keys via "inheritance" style extension
  for k in pairs(valid_configuration_keys) do
    if result[k] == nil then
      result[k] = get_value(k)
    end
  end

  return result
end

-- List of options that are shared by more than one layout.
local shared_options = {
  width = { "How wide to make Telescope's entire layout", "See |resolver.resolve_width()|" },
  height = { "How tall to make Telescope's entire layout", "See |resolver.resolve_height()|" },
  mirror = "Flip the location of the results/prompt and preview windows",
  scroll_speed = "The number of lines to scroll through the previewer",
}

-- Used for generating vim help documentation.
layout_strategies._format = function(name)
  local strategy_config = layout_strategies._configurations[name]
  if vim.tbl_isempty(strategy_config) then
    return {}
  end

  local results = { "<pre>", "`picker.layout_config` shared options:" }

  local strategy_keys = vim.tbl_keys(strategy_config)
  table.sort(strategy_keys, function(a, b)
    return a < b
  end)

  local add_value = function(k, val)
    if type(val) == "string" then
      table.insert(results, string.format("  - %s: %s", k, val))
    elseif type(val) == "table" then
      table.insert(results, string.format("  - %s:", k))
      for _, line in ipairs(val) do
        table.insert(results, string.format("    - %s", line))
      end
    else
      error("Unknown type:" .. type(val))
    end
  end

  for _, k in ipairs(strategy_keys) do
    if shared_options[k] then
      add_value(k, strategy_config[k])
    end
  end

  table.insert(results, "")
  table.insert(results, "`picker.layout_config` unique options:")

  for _, k in ipairs(strategy_keys) do
    if not shared_options[k] then
      add_value(k, strategy_config[k])
    end
  end

  table.insert(results, "</pre>")
  return results
end

--@param name string: the name to be assigned to the layout
--@param layout_config table: table where keys are the available options for the layout
--@param layout function: function with signature
--          function(self, max_columns, max_lines, layout_config): table
--        the returned table is the sizing and location information for the parts of the picker
--@retun function: wrapped function that inputs a validated layout_config into the `layout` function
local function make_documented_layout(name, layout_config, layout)
  -- Save configuration data to be used by documentation
  layout_strategies._configurations[name] = layout_config

  -- Return new function that always validates configuration
  return function(self, max_columns, max_lines, override_layout)
    return layout(
      self,
      max_columns,
      max_lines,
      validate_layout_config(
        name,
        layout_config,
        vim.tbl_deep_extend("keep", if_nil(override_layout, {}), if_nil(self.layout_config, {}))
      )
    )
  end
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
---@eval { ["description"] = require('telescope.pickers.layout_strategies')._format("horizontal") }
---
layout_strategies.horizontal = make_documented_layout(
  "horizontal",
  vim.tbl_extend("error", shared_options, {
    preview_width = { "Change the width of Telescope's preview window", "See |resolver.resolve_width()|" },
    preview_cutoff = "When columns are less than this value, the preview will be disabled",
    prompt_position = { "Where to place prompt window.", "Available Values: 'bottom', 'top'" },
  }),
  function(self, max_columns, max_lines, layout_config)
    local initial_options = p_window.get_initial_window_options(self)
    local preview = initial_options.preview
    local results = initial_options.results
    local prompt = initial_options.prompt

    local tbln
    max_lines, tbln = calc_tabline(max_lines)

    local width_opt = layout_config.width
    local picker_width = resolve.resolve_width(width_opt)(self, max_columns, max_lines)
    local width_padding = math.floor((max_columns - picker_width) / 2)

    local height_opt = layout_config.height
    local picker_height = resolve.resolve_height(height_opt)(self, max_columns, max_lines)
    local height_padding = math.floor((max_lines - picker_height) / 2)

    if self.previewer and max_columns >= layout_config.preview_cutoff then
      preview.width = resolve.resolve_width(if_nil(layout_config.preview_width, function(_, cols)
        if cols < 150 then
          return math.floor(cols * 0.4)
        elseif cols < 200 then
          return 80
        else
          return 120
        end
      end))(self, picker_width, max_lines)
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
    if layout_config.prompt_position == "top" then
      prompt.line = height_padding
      results.line = prompt.line + prompt.height + 2
    elseif layout_config.prompt_position == "bottom" then
      results.line = height_padding
      prompt.line = results.line + results.height + 2
    else
      error("Unknown prompt_position: " .. tostring(self.window.prompt_position) .. "\n" .. vim.inspect(layout_config))
    end

    if tbln then
      prompt.line = prompt.line + 1
      results.line = results.line + 1
      preview.line = preview.line + 1
    end

    return {
      preview = self.previewer and preview.width > 0 and preview,
      results = results,
      prompt = prompt,
    }
  end
)

--- Centered layout with a combined block of the prompt
--- and results aligned to the middle of the screen.
--- The preview window is then placed in the remaining space above.
--- Particularly useful for creating dropdown menus
--- (see |telescope.themes| and |themes.get_dropdown()|`).
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
---@eval { ["description"] = require("telescope.pickers.layout_strategies")._format("center") }
---
layout_strategies.center = make_documented_layout(
  "center",
  vim.tbl_extend("error", shared_options, {
    preview_cutoff = "When lines are less than this value, the preview will be disabled",
  }),
  function(self, max_columns, max_lines, layout_config)
    local initial_options = p_window.get_initial_window_options(self)
    local preview = initial_options.preview
    local results = initial_options.results
    local prompt = initial_options.prompt

    local tbln
    max_lines, tbln = calc_tabline(max_lines)

    -- This sets the width for the whole layout
    local width_opt = layout_config.width
    local width = resolve.resolve_width(width_opt)(self, max_columns, max_lines)

    -- This sets the number of results displayed
    local res_height_opt = layout_config.height
    local res_height = resolve.resolve_height(res_height_opt)(self, max_columns, max_lines)

    local max_results = (res_height > max_lines and max_lines or res_height)
    local max_width = (width > max_columns and max_columns or width)

    local bs = get_border_size(self)

    prompt.height = 1
    results.height = max_results

    prompt.width = max_width
    results.width = max_width
    preview.width = max_width

    -- Align the prompt and results so halfway up the screen is
    -- in the middle of this combined block
    prompt.line = (max_lines / 2) - ((max_results + (bs * 2)) / 2)
    results.line = prompt.line + 1 + bs

    preview.line = 1

    if self.previewer and max_lines >= layout_config.preview_cutoff then
      preview.height = math.floor(prompt.line - (2 + bs))
    else
      preview.height = 0
    end

    results.col = math.ceil((max_columns / 2) - (width / 2) - bs)
    prompt.col = results.col
    preview.col = results.col

    if tbln then
      prompt.line = prompt.line + 1
      results.line = results.line + 1
      preview.line = preview.line + 1
    end

    return {
      preview = self.previewer and preview.height > 0 and preview,
      results = results,
      prompt = prompt,
    }
  end
)

--- Cursor layout dynamically positioned below the cursor if possible.
--- If there is no place below the cursor it will be placed above.
---
--- <pre>
--- ┌──────────────────────────────────────────────────┐
--- │                                                  │
--- │   █                                              │
--- │   ┌──────────────┐┌─────────────────────┐        │
--- │   │    Prompt    ││      Preview        │        │
--- │   ├──────────────┤│      Preview        │        │
--- │   │    Result    ││      Preview        │        │
--- │   │    Result    ││      Preview        │        │
--- │   └──────────────┘└─────────────────────┘        │
--- │                                         █        │
--- │                                                  │
--- │                                                  │
--- │                                                  │
--- │                                                  │
--- │                                                  │
--- └──────────────────────────────────────────────────┘
--- </pre>
layout_strategies.cursor = make_documented_layout(
  "cursor",
  vim.tbl_extend("error", shared_options, {
    preview_width = { "Change the width of Telescope's preview window", "See |resolver.resolve_width()|" },
    preview_cutoff = "When columns are less than this value, the preview will be disabled",
  }),
  function(self, max_columns, max_lines, layout_config)
    local initial_options = p_window.get_initial_window_options(self)
    local preview = initial_options.preview
    local results = initial_options.results
    local prompt = initial_options.prompt

    local height_opt = layout_config.height
    local height = resolve.resolve_height(height_opt)(self, max_columns, max_lines)

    local width_opt = layout_config.width
    local width = resolve.resolve_width(width_opt)(self, max_columns, max_lines)

    local max_width = (width > max_columns and max_columns or width)

    local bs = get_border_size(self)

    prompt.height = 1
    results.height = height
    preview.height = results.height + prompt.height + bs

    if self.previewer and max_columns >= layout_config.preview_cutoff then
      preview.width = resolve.resolve_width(if_nil(layout_config.preview_width, function(_, cols)
        -- By default, previewer takes 2/3 of the layout
        return 2 * math.floor(max_width / 3)
      end))(self, max_width, max_lines)
    else
      preview.width = 0
    end

    prompt.width = max_width - preview.width
    results.width = prompt.width

    local total_height = preview.height + (bs * 2)
    local total_width = prompt.width + (bs * 2) + preview.width + bs

    local position = vim.api.nvim_win_get_position(0)
    local top_left = {
      line = vim.fn.winline() + position[1] + bs,
      col = vim.fn.wincol() + position[2],
    }
    local bot_right = {
      line = top_left.line + total_height - 1,
      col = top_left.col + total_width - 1,
    }

    if bot_right.line > max_lines then
      -- position above current line
      top_left.line = top_left.line - total_height - 1
    end
    if bot_right.col >= max_columns then
      -- cap to the right of the screen
      top_left.col = max_columns - total_width
    end

    prompt.line = top_left.line
    results.line = prompt.line + bs + 1
    preview.line = prompt.line

    prompt.col = top_left.col
    results.col = prompt.col
    preview.col = results.col + (bs * 2) + results.width

    return {
      preview = self.previewer and preview.width > 0 and preview,
      results = results,
      prompt = prompt,
    }
  end
)

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
---@eval { ["description"] = require("telescope.pickers.layout_strategies")._format("vertical") }
---
layout_strategies.vertical = make_documented_layout(
  "vertical",
  vim.tbl_extend("error", shared_options, {
    preview_cutoff = "When lines are less than this value, the preview will be disabled",
    preview_height = { "Change the height of Telescope's preview window", "See |resolver.resolve_height()|" },
    prompt_position = { "(unimplemented, but we plan on supporting)" },
  }),
  function(self, max_columns, max_lines, layout_config)
    local initial_options = p_window.get_initial_window_options(self)
    local preview = initial_options.preview
    local results = initial_options.results
    local prompt = initial_options.prompt

    local tbln
    max_lines, tbln = calc_tabline(max_lines)

    local width_opt = layout_config.width
    local picker_width = resolve.resolve_width(width_opt)(self, max_columns, max_lines)
    local width_padding = math.floor((max_columns - picker_width) / 2)

    local height_opt = layout_config.height
    local picker_height = resolve.resolve_height(height_opt)(self, max_columns, max_lines)
    local height_padding = math.floor((max_lines - picker_height) / 2)

    if self.previewer and max_lines >= layout_config.preview_cutoff then
      preview.width = picker_width
    else
      preview.width = 0
    end
    results.width = picker_width
    prompt.width = picker_width

    local preview_total = 0
    preview.height = 0
    if self.previewer and max_lines >= layout_config.preview_cutoff then
      preview.height = resolve.resolve_height(if_nil(layout_config.preview_height, 0.5))(
        self,
        max_columns,
        picker_height
      )

      preview_total = preview.height + 2
    end

    prompt.height = 1
    results.height = picker_height - preview_total - prompt.height - 2

    results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

    if not layout_config.mirror then
      preview.line = height_padding
      results.line = (preview.height == 0) and preview.line or preview.line + preview.height + 2
      prompt.line = results.line + results.height + 2
    else
      prompt.line = height_padding
      results.line = prompt.line + prompt.height + 2
      preview.line = results.line + results.height + 2
    end

    if tbln then
      prompt.line = prompt.line + 1
      results.line = results.line + 1
      preview.line = preview.line + 1
    end

    return {
      preview = self.previewer and preview.height > 0 and preview,
      results = results,
      prompt = prompt,
    }
  end
)

--- Flex layout swaps between `horizontal` and `vertical` strategies based on the window width
---  -  Supports |layout_strategies.vertical| or |layout_strategies.horizontal| features
---
---@eval { ["description"] = require("telescope.pickers.layout_strategies")._format("flex") }
---
layout_strategies.flex = make_documented_layout(
  "flex",
  vim.tbl_extend("error", shared_options, {
    flip_columns = "The number of columns required to move to horizontal mode",
    flip_lines = "The number of lines required to move to horizontal mode",
    vertical = "Options to pass when switching to vertical layout",
    horizontal = "Options to pass when switching to horizontal layout",
  }),
  function(self, max_columns, max_lines, layout_config)
    local flip_columns = if_nil(layout_config.flip_columns, 100)
    local flip_lines = if_nil(layout_config.flip_lines, 20)

    if max_columns < flip_columns and max_lines > flip_lines then
      return layout_strategies.vertical(self, max_columns, max_lines, layout_config.vertical)
    else
      return layout_strategies.horizontal(self, max_columns, max_lines, layout_config.horizontal)
    end
  end
)

layout_strategies.current_buffer = make_documented_layout("current_buffer", {
  -- No custom options.
  -- height, width ignored
}, function(self, _, _, _)
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
end)

--- Bottom pane can be used to create layouts similar to "ivy".
---
--- For an easy ivy configuration, see |themes.get_ivy()|
layout_strategies.bottom_pane = make_documented_layout(
  "bottom_pane",
  vim.tbl_extend("error", shared_options, {
    -- No custom options...
  }),
  function(self, max_columns, max_lines, layout_config)
    local initial_options = p_window.get_initial_window_options(self)
    local results = initial_options.results
    local prompt = initial_options.prompt
    local preview = initial_options.preview

    local result_height = if_nil(resolve.resolve_height(layout_config.height)(self, max_columns, max_lines), 25)

    local prompt_width = max_columns
    local col = 0

    local has_border = not not self.window.border
    if has_border then
      col = 1
      prompt_width = prompt_width - 2
    end

    local left_side_width
    if self.previewer then
      left_side_width = math.floor(prompt_width / 2)

      local base_col
      if layout_config.mirror then
        base_col = 0
      else
        base_col = left_side_width + 1
      end

      if has_border then
        preview = vim.tbl_deep_extend("force", {
          col = base_col + 2,
          line = max_lines - result_height + 1,
          width = prompt_width - left_side_width - 2,
          height = result_height - 1,
        }, preview)
      else
        preview = vim.tbl_deep_extend("force", {
          col = base_col,
          line = max_lines - result_height,
          width = prompt_width - left_side_width,
          height = result_height,
        }, preview)
      end
    else
      preview = nil
      left_side_width = prompt_width
    end

    local result_col
    if layout_config.mirror and self.previewer then
      result_col = left_side_width + 2
      if has_border then
        left_side_width = left_side_width - 2
      end
    else
      result_col = col
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
        col = result_col,
        height = result_height,
        width = left_side_width,
      }),
    }
  end
)

layout_strategies._validate_layout_config = validate_layout_config

return layout_strategies
