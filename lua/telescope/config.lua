local log = require('telescope.log')

-- Keep the values around between reloads
_TelescopeConfigurationValues = _TelescopeConfigurationValues or {}

local function first_non_null(...)
  local n = select('#', ...)
  for i = 1, n do
    local value = select(i, ...)

    if value ~= nil then
      return value
    end
  end
end

local dedent = function(str, leave_indent)
  -- find minimum common indent across lines
  local indent = nil
  for line in str:gmatch('[^\n]+') do
    local line_indent = line:match('^%s+') or ''
    if indent == nil or #line_indent < #indent then
      indent = line_indent
    end
  end
  if indent == nil or #indent == 0 then
    -- no minimum common indent
    return str
  end
  local left_indent = (' '):rep(leave_indent or 0)
  -- create a pattern for the indent
  indent = indent:gsub('%s', '[ \t]')
  -- strip it from the first line
  str = str:gsub('^'..indent, left_indent)
  -- strip it from the remaining lines
  str = str:gsub('[\n]'..indent, '\n' .. left_indent)
  return str
end


local sorters = require('telescope.sorters')

-- TODO: Add other major configuration points here.
-- selection_strategy

local config = {}

config.values = _TelescopeConfigurationValues
config.descriptions = {}

-- A table of all the usual defaults for telescope.
-- Keys will be the name of the default,
-- values will be a list where:
-- - first entry is the value
-- - second entry is the description of the option
local telescope_defaults = {}

-- @param user_defaults table: a table where keys are the names of options,
--    and values are the ones the user wants
-- @param tele_defaults table: (optional) a table containing all of the defaults
--    for telescope [defaults to `telescope_defaults`]
function config.set_defaults(user_defaults,tele_defaults)
  user_defaults = user_defaults or {}
  tele_defaults = tele_defaults or telescope_defaults

  if user_defaults.layout_default then
    if user_defaults.layout_config == nil then
      log.info("Using 'layout_default' in setup() is deprecated. Use 'layout_config' instead.")
      user_defaults.layout_config = user_defaults.layout_default
    else
      error("Using 'layout_default' in setup() is deprecated. Remove this key and use 'layout_config' instead.")
    end
  end

  local function get(name, default_val)
    if name == "layout_config" then
      return vim.tbl_deep_extend("force", default_val or {}, user_defaults[name] or {}, config.values[name] or {})
    end
    return first_non_null(user_defaults[name], config.values[name], default_val)
  end

  local function set(name, default_val, description)
    -- TODO(doc): Once we have descriptions for all of these, then we can add this back in.
    -- assert(description, "Config values must always have a description")

    config.values[name] = get(name, default_val)
    if description then
      config.descriptions[name] = dedent(description)
    end
  end

  for key, info in pairs(tele_defaults) do
    set(key, info[1], info[2])
  end

  local M = {}
  M.get = get
  return M
end

telescope_defaults["sorting_strategy"] = { "descending", [[
    Determines the direction "better" results are sorted towards.

    Available options are:
    - "descending" (default)
    - "ascending"]]}

telescope_defaults["selection_strategy"] = { "reset", [[
    Determines how the cursor acts after each sort iteration.

    Available options are:
    - "reset" (default)
    - "follow"
    - "row"]]}

telescope_defaults["scroll_strategy"] = {"cycle", [[
    Determines what happens you try to scroll past view of the picker.

    Available options are:
    - "cycle" (default)
    - "limit"]]}

telescope_defaults["layout_strategy"] = {"horizontal", [[
    Determines the default layout of Telescope pickers.
    See |telescope.layout| for details of the available strategies.

    Default: 'horizontal']]}

local layout_config_defaults = {
    width = 0.8,
    height = 0.9,

    horizontal = {
      prompt_position = "bottom",
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
]], vim.inspect(layout_config_defaults, { newline = "\n    ", indent = "  " }))

telescope_defaults["layout_config"] = {layout_config_defaults, layout_config_description}

telescope_defaults["winblend"] = {0}
telescope_defaults["preview_cutoff"] = {120}

telescope_defaults["prompt_prefix"] = {"> ", [[
    Will be shown in front of the prompt.

    Default: '> ']]}
telescope_defaults["selection_caret"] = {"> ", [[
    Will be shown in front of the selection.

    Default: '> ']]}
telescope_defaults["entry_prefix"] = {"  ", [[
    Prefix in front of each result entry. Current selection not included.

    Default: '  ']]}
telescope_defaults["initial_mode"] = {"insert"}

telescope_defaults["border"] = {{}}
telescope_defaults["borderchars"] = {{ '─', '│', '─', '│', '╭', '╮', '╯', '╰'}}

telescope_defaults["get_status_text"] = {function(self)
    local xx = (self.stats.processed or 0) - (self.stats.filtered or 0)
    local yy = self.stats.processed or 0
    if xx == 0 and yy == 0 then return "" end

    return string.format("%s / %s", xx, yy)
  end}

  -- Builtin configuration

  -- List that will be executed.
  --    Last argument will be the search term (passed in during execution)
telescope_defaults["vimgrep_arguments"] = {
      {'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case'}
  }
telescope_defaults["use_less"] = {true}
telescope_defaults["color_devicons"] = {true}

telescope_defaults["set_env"] = {nil}

  -- TODO: Add motions to keybindings

  -- To disable a keymap, put [map] = false
  --        So, to not map "<C-n>", just put
  --
  --            ...,
  --            ["<C-n>"] = false,
  --            ...,
  --
  --        Into your config.
  --
  -- Otherwise, just set the mapping to the function that you want it to be.
  --
  --            ...,
  --            ["<C-i>"] = actions.select_default
  --            ...,
  --

  -- Hmmm, these don't make sense really?
telescope_defaults["mappings"] = {{}}
telescope_defaults["default_mappings"] = {nil}

telescope_defaults["generic_sorter"] = {sorters.get_generic_fuzzy_sorter}
telescope_defaults["prefilter_sorter"] = {sorters.prefilter}
telescope_defaults["file_sorter"] = {sorters.get_fuzzy_file}

telescope_defaults["file_ignore_patterns"] = {nil}

telescope_defaults["file_previewer"] = {
  function(...) return require('telescope.previewers').vim_buffer_cat.new(...) end}
telescope_defaults["grep_previewer"] = {
  function(...) return require('telescope.previewers').vim_buffer_vimgrep.new(...) end}
telescope_defaults["qflist_previewer"] = {
  function(...) return require('telescope.previewers').vim_buffer_qflist.new(...) end}
telescope_defaults["buffer_previewer_maker"] = {
  function(...) return require('telescope.previewers').buffer_previewer_maker(...) end}

function config.clear_defaults()
  for k, _ in pairs(config.values) do
    config.values[k] = nil
  end
end

config.set_defaults()


return config
