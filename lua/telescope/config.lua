local strings = require "plenary.strings"
local log = require "telescope.log"
local sorters = require "telescope.sorters"
local if_nil = vim.F.if_nil

-- Keep the values around between reloads
_TelescopeConfigurationValues = _TelescopeConfigurationValues or {}
_TelescopeConfigurationPickers = _TelescopeConfigurationPickers or {}

local function first_non_null(...)
  local n = select("#", ...)
  for i = 1, n do
    local value = select(i, ...)

    if value ~= nil then
      return value
    end
  end
end

-- A function that creates an amended copy of the `base` table,
-- by replacing keys at "level 2" that match keys in "level 1" in `priority`,
-- and then performs a deep_extend.
-- May give unexpected results if used with tables of "depth"
-- greater than 2.
local smarter_depth_2_extend = function(priority, base)
  local result = {}
  for key, val in pairs(base) do
    if type(val) ~= "table" then
      result[key] = first_non_null(priority[key], val)
    else
      result[key] = {}
      for k, v in pairs(val) do
        result[key][k] = first_non_null(priority[k], v)
      end
    end
  end
  result = vim.tbl_deep_extend("keep", priority, result)
  return result
end

-- TODO: Add other major configuration points here.
-- selection_strategy

local config = {}

config.values = _TelescopeConfigurationValues
config.descriptions = {}
config.pickers = _TelescopeConfigurationPickers

function config.set_pickers(pickers)
  pickers = if_nil(pickers, {})

  for k, v in pairs(pickers) do
    config.pickers[k] = v
  end
end

local layout_config_defaults = {
  width = 0.8,
  height = 0.9,

  horizontal = {
    prompt_position = "bottom",
    preview_cutoff = 120,
  },

  vertical = {
    preview_cutoff = 40,
  },

  center = {
    preview_cutoff = 40,
  },
}

local layout_config_description = string.format([[
    Determines the default configuration values for layout strategies.
    See |telescope.layout| for details of the configurations options for
    each strategy.

    Allows setting defaults for all strategies as top level options and
    for overriding for specific options.
    For example, the default values below set the default width to 80%% of
    the screen width for all strategies except 'center', which has width
    of 50%% of the screen width.

    Default: %s
]], vim.inspect(
  layout_config_defaults,
  { newline = "\n    ", indent = "  " }
))

-- A table of all the usual defaults for telescope.
-- Keys will be the name of the default,
-- values will be a list where:
-- - first entry is the value
-- - second entry is the description of the option

local telescope_defaults = {

  sorting_strategy = {
    "descending",
    [[
    Determines the direction "better" results are sorted towards.

    Available options are:
    - "descending" (default)
    - "ascending"]],
  },

  selection_strategy = {
    "reset",
    [[
    Determines how the cursor acts after each sort iteration.

    Available options are:
    - "reset" (default)
    - "follow"
    - "row"]],
  },

  scroll_strategy = {
    "cycle",
    [[
    Determines what happens you try to scroll past view of the picker.

    Available options are:
    - "cycle" (default)
    - "limit"]],
  },

  layout_strategy = {
    "horizontal",
    [[
    Determines the default layout of Telescope pickers.
    See |telescope.layout| for details of the available strategies.

    Default: 'horizontal']],
  },

  layout_config = { layout_config_defaults, layout_config_description },

  winblend = { 0 },

  prompt_prefix = { "> ", [[
    Will be shown in front of the prompt.

    Default: '> ']]
  },

  selection_caret = { "> ", [[
    Will be shown in front of the selection.

    Default: '> ']]
  },

  entry_prefix = { "  ", [[
    Prefix in front of each result entry. Current selection not included.

    Default: '  ']]
  },

  initial_mode = { "insert" },

  border = { true, [[
    Boolean defining if borders are added to Telescope windows.

    Default: true]]
  },

  borderchars = { { "─", "│", "─", "│", "╭", "╮", "╯", "╰" } },

  get_status_text = {
    function(self)
      local xx = (self.stats.processed or 0) - (self.stats.filtered or 0)
      local yy = self.stats.processed or 0
      if xx == 0 and yy == 0 then
        return ""
      end

      return string.format("%s / %s", xx, yy)
    end,
  },

  dynamic_preview_title = {
    false,
    [[
    Will change the title of the preview window dynamically, where it
    is supported. Means the preview window will for example show the
    full filename.

    Default: false
    ]],
  },

  -- Builtin configuration

  -- List that will be executed.
  --    Last argument will be the search term (passed in during execution)
  vimgrep_arguments = {
    { "rg", "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
  },

  use_less = { true },

  color_devicons = { true },

  set_env = { nil },

  mappings = {
    {}, [[
    Your mappings to override telescope's default mappings.

    Format is:
    {
      mode = { ..keys }
    }

    where {mode} is the one character letter for a mode
    ('i' for insert, 'n' for normal).

    For example:

    mappings = {
      i = {
        ["<esc>"] = require('telescope.actions').close,
      },
    }


    To disable a keymap, put [map] = false
      So, to not map "<C-n>", just put

        ...,
        ["<C-n>"] = false,
        ...,

      Into your config.


    otherwise, just set the mapping to the function that you want it to be.

        ...,
        ["<C-i>"] = require('telescope.actions').select_default,
        ...,

    If the function you want is part of `telescope.actions`, then you can simply give a string.
      For example, the previous option is equivalent to:

        ...,
        ["<C-i>"] = "select_default",
        ...,

    You can also add other mappings using tables with `type = "command"`.
      For example:

        ...,
        ["jj"] = { "<esc>", type = "command" },
        ["kk"] = { "<cmd>echo \"Hello, World!\"<cr>", type = "command" },)
        ...,
    ]],
  },

  default_mappings = {
    nil,
    [[
    Not recommended to use except for advanced users.

    Will allow you to completely remove all of telescope's default maps
    and use your own.
    ]],
  },

  generic_sorter = { sorters.get_generic_fuzzy_sorter },
  prefilter_sorter = { sorters.prefilter },
  file_sorter = { sorters.get_fuzzy_file },

  file_ignore_patterns = { nil },

  file_previewer = {
    function(...)
      return require("telescope.previewers").vim_buffer_cat.new(...)
    end,
  },
  grep_previewer = {
    function(...)
      return require("telescope.previewers").vim_buffer_vimgrep.new(...)
    end,
  },
  qflist_previewer = {
    function(...)
      return require("telescope.previewers").vim_buffer_qflist.new(...)
    end,
  },
  buffer_previewer_maker = {
    function(...)
      return require("telescope.previewers").buffer_previewer_maker(...)
    end,
  },
}

-- @param user_defaults table: a table where keys are the names of options,
--    and values are the ones the user wants
-- @param tele_defaults table: (optional) a table containing all of the defaults
--    for telescope [defaults to `telescope_defaults`]
function config.set_defaults(user_defaults, tele_defaults)
  user_defaults = if_nil(user_defaults, {})
  tele_defaults = if_nil(tele_defaults, telescope_defaults)

  if user_defaults.layout_defaults then
    if user_defaults.layout_config == nil then
      log.info "Using 'layout_defaults' in setup() is deprecated. Use 'layout_config' instead."
      user_defaults.layout_config = user_defaults.layout_defaults
    else
      error "Using 'layout_defaults' in setup() is deprecated. Remove this key and use 'layout_config' instead."
    end
  end

  local function get(name, default_val)
    if name == "layout_config" then
      return smarter_depth_2_extend(
        if_nil(user_defaults[name], {}),
        vim.tbl_deep_extend("keep", if_nil(config.values[name], {}), if_nil(default_val, {}))
      )
    end
    return first_non_null(user_defaults[name], config.values[name], default_val)
  end

  local function set(name, default_val, description)
    -- TODO(doc): Once we have descriptions for all of these, then we can add this back in.
    -- assert(description, "Config values must always have a description")

    config.values[name] = get(name, default_val)
    if description then
      config.descriptions[name] = strings.dedent(description)
    end
  end

  for key, info in pairs(tele_defaults) do
    set(key, info[1], info[2])
  end

  local M = {}
  M.get = get
  return M
end

function config.clear_defaults()
  for k, _ in pairs(config.values) do
    config.values[k] = nil
  end
end

config.set_defaults()

return config
