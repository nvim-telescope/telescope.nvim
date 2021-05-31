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

function config.set_defaults(defaults)
  defaults = defaults or {}

  local function get(name, default_val)
    return first_non_null(defaults[name], config.values[name], default_val)
  end

  local function set(name, default_val, description)
    -- TODO(doc): Once we have descriptions for all of these, then we can add this back in.
    -- assert(description, "Config values must always have a description")

    config.values[name] = get(name, default_val)
    if description then
      config.descriptions[name] = dedent(description)
    end
  end

  set("sorting_strategy", "descending", [[
    Determines the direction "better" results are sorted towards.

    Available options are:
    - "descending" (default)
    - "ascending"]])

  set("selection_strategy", "reset", [[
    Determines how the cursor acts after each sort iteration.

    Available options are:
    - "reset" (default)
    - "follow"
    - "row"]])

  set("scroll_strategy", "cycle", [[
    Determines what happens you try to scroll past view of the picker.

    Available options are:
    - "cycle" (default)
    - "limit"]])

  set("layout_strategy", "horizontal")
  set("layout_defaults", {})

  set("width", 0.75)
  set("winblend", 0)
  set("prompt_position", "bottom")
  set("preview_cutoff", 120)

  set("results_height", 1)
  set("results_width", 0.8)

  set("prompt_prefix", "> ", [[
    Will be shown in front of the prompt.

    Default: '> ']])
  set("selection_caret", "> ", [[
    Will be shown in front of the selection.

    Default: '> ']])
  set("entry_prefix", "  ", [[
    Prefix in front of each result entry. Current selection not included.

    Default: '  ']])
  set("initial_mode", "insert")

  set("border", {})
  set("borderchars", { '─', '│', '─', '│', '╭', '╮', '╯', '╰'})

  set("get_status_text", function(self)
    local xx = (self.stats.processed or 0) - (self.stats.filtered or 0)
    local yy = self.stats.processed or 0
    if xx == 0 and yy == 0 then return "" end

    return string.format("%s / %s", xx, yy)
  end)

  -- Builtin configuration

  -- List that will be executed.
  --    Last argument will be the search term (passed in during execution)
  set("vimgrep_arguments",
      {'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case'}
  )
  set("use_less", true)
  set("color_devicons", true)

  set("set_env", nil)

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
  set("mappings", {})
  set("default_mappings", nil)

  set("generic_sorter", sorters.get_generic_fuzzy_sorter)
  set("prefilter_sorter", sorters.prefilter)
  set("file_sorter", sorters.get_fuzzy_file)

  set("file_ignore_patterns", nil)

  set("file_previewer", function(...) return require('telescope.previewers').vim_buffer_cat.new(...) end)
  set("grep_previewer", function(...) return require('telescope.previewers').vim_buffer_vimgrep.new(...) end)
  set("qflist_previewer", function(...) return require('telescope.previewers').vim_buffer_qflist.new(...) end)
  set("buffer_previewer_maker", function(...) return require('telescope.previewers').buffer_previewer_maker(...) end)
end

function config.clear_defaults()
  for k, _ in pairs(config.values) do
    config.values[k] = nil
  end
end

config.set_defaults()


return config
