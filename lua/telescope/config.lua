local strings = require "plenary.strings"
local deprecated = require "telescope.deprecated"
local sorters = require "telescope.sorters"
local if_nil = vim.F.if_nil
local os_sep = require("plenary.path").path.sep

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
  for key, val in pairs(priority) do
    if type(val) ~= "table" then
      result[key] = first_non_null(val, result[key])
    else
      result[key] = vim.tbl_extend("keep", val, result[key] or {})
    end
  end
  return result
end

local resolve_table_opts = function(priority, base)
  if priority == false or (priority == nil and base == false) then
    return false
  end
  if priority == nil and type(base) == "table" then
    return base
  end
  return smarter_depth_2_extend(priority, base)
end

-- TODO: Add other major configuration points here.
-- selection_strategy

local config = {}
config.smarter_depth_2_extend = smarter_depth_2_extend
config.resolve_table_opts = resolve_table_opts

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

  horizontal = {
    width = 0.8,
    height = 0.9,
    prompt_position = "bottom",
    preview_cutoff = 120,
  },

  vertical = {
    width = 0.8,
    height = 0.9,
    prompt_position = "bottom",
    preview_cutoff = 40,
  },

  center = {
    width = 0.8,
    height = 0.9,
    preview_cutoff = 40,
  },

  cursor = {
    width = 0.8,
    height = 0.9,
    preview_cutoff = 40,
  },

  bottom_pane = {
    height = 25,
  },
}

local layout_config_description = string.format(
  [[
    Determines the default configuration values for layout strategies.
    See |telescope.layout| for details of the configurations options for
    each strategy.

    Allows setting defaults for all strategies as top level options and
    for overriding for specific options.
    For example, the default values below set the default width to 80%% of
    the screen width for all strategies except 'center', which has width
    of 50%% of the screen width.

    Default: %s
]],
  vim.inspect(layout_config_defaults, { newline = "\n    ", indent = "  " })
)

-- A table of all the usual defaults for telescope.
-- Keys will be the name of the default,
-- values will be a list where:
-- - first entry is the value
-- - second entry is the description of the option

local telescope_defaults = {}
config.descriptions_order = {}
local append = function(name, val, doc)
  telescope_defaults[name] = { val, doc }
  table.insert(config.descriptions_order, name)
end

append(
  "sorting_strategy",
  "descending",
  [[
  Determines the direction "better" results are sorted towards.

  Available options are:
  - "descending" (default)
  - "ascending"]]
)

append(
  "selection_strategy",
  "reset",
  [[
  Determines how the cursor acts after each sort iteration.

  Available options are:
  - "reset" (default)
  - "follow"
  - "row"
  - "closest"]]
)

append(
  "scroll_strategy",
  "cycle",
  [[
  Determines what happens if you try to scroll past the view of the
  picker.

  Available options are:
  - "cycle" (default)
  - "limit"]]
)

append(
  "layout_strategy",
  "horizontal",
  [[
  Determines the default layout of Telescope pickers.
  See |telescope.layout| for details of the available strategies.

  Default: 'horizontal']]
)

append("layout_config", layout_config_defaults, layout_config_description)

append(
  "winblend",
  0,
  [[
  Configure winblend for telescope floating windows. See |winblend| for
  more information.

  Default: 0]]
)

append(
  "prompt_prefix",
  "> ",
  [[
  The character(s) that will be shown in front of Telescope's prompt.

  Default: '> ']]
)

append(
  "selection_caret",
  "> ",
  [[
  The character(s) that will be shown in front of the current selection.


  Default: '> ']]
)

append(
  "entry_prefix",
  "  ",
  [[
  Prefix in front of each result entry. Current selection not included.

  Default: '  ']]
)

append(
  "initial_mode",
  "insert",
  [[
  Determines in which mode telescope starts. Valid Keys:
  `insert` and `normal`.

  Default: "insert"]]
)

append(
  "border",
  true,
  [[
  Boolean defining if borders are added to Telescope windows.

  Default: true]]
)

append(
  "path_display",
  {},
  [[
  Determines how file paths are displayed

  path_display can be set to an array with a combination of:
  - "hidden"    hide file names
  - "tail"      only display the file name, and not the path
  - "absolute"  display absolute paths
  - "smart"     remove as much from the path as possible to only show
                the difference between the displayed paths
  - "shorten"   only display the first character of each directory in
                the path
  - "truncate"  truncates the start of the path when the whole path will
                not fit. To increase the the gap between the path and the edge.
                set truncate to number `truncate = 3`

  You can also specify the number of characters of each directory name
  to keep by setting `path_display.shorten = num`.
    e.g. for a path like
      `alpha/beta/gamma/delta.txt`
    setting `path_display.shorten = 1` will give a path like:
      `a/b/g/delta.txt`
    Similarly, `path_display.shorten = 2` will give a path like:
      `al/be/ga/delta.txt`

  path_display can also be set to 'hidden' string to hide file names

  path_display can also be set to a function for custom formatting of
  the path display. Example:

      -- Format path as "file.txt (path\to\file\)"
      path_display = function(opts, path)
        local tail = require("telescope.utils").path_tail(path)
        return string.format("%s (%s)", tail, path)
      end,

  Default: {}]]
)

append(
  "borderchars",
  { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
  [[
  Set the borderchars of telescope floating windows. It has to be a
  table of 8 string values.

  Default: { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }]]
)

append(
  "get_status_text",
  function(self)
    local xx = (self.stats.processed or 0) - (self.stats.filtered or 0)
    local yy = self.stats.processed or 0
    if xx == 0 and yy == 0 then
      return ""
    end

    -- local status_icon
    -- if opts.completed then
    --   status_icon = "✔️"
    -- else
    --   status_icon = "*"
    -- end
    return string.format("%s / %s", xx, yy)
  end,
  [[
  A function that determines what the virtual text looks like.
  Signature: function(picker) -> str

  Default: function that shows current count / all]]
)

append(
  "dynamic_preview_title",
  false,
  [[
  Will change the title of the preview window dynamically, where it
  is supported. For example, the preview window's title could show up as
  the full filename.

  Default: false]]
)

append(
  "history",
  {
    path = vim.fn.stdpath "data" .. os_sep .. "telescope_history",
    limit = 100,
    handler = function(...)
      return require("telescope.actions.history").get_simple_history(...)
    end,
  },
  [[
  This field handles the configuration for prompt history.
  By default it is a table, with default values (more below).
  To disable history, set it to false.

  Currently mappings still need to be added, Example:
    mappings = {
      i = {
        ["<C-Down>"] = require('telescope.actions').cycle_history_next,
        ["<C-Up>"] = require('telescope.actions').cycle_history_prev,
      },
    },

  Fields:
    - path:    The path to the telescope history as string.
               default: stdpath("data")/telescope_history
    - limit:   The amount of entries that will be written in the
               history.
               Warning: If limit is set to nil it will grown unbound.
               default: 100
    - handler: A lua function that implements the history.
               This is meant as a developer setting for extensions to
               override the history handling, e.g.,
               https://github.com/nvim-telescope/telescope-smart-history.nvim,
               which allows context sensitive (cwd + picker) history.

               Default:
               require('telescope.actions.history').get_simple_history]]
)

append(
  "cache_picker",
  {
    num_pickers = 1,
    limit_entries = 1000,
  },
  [[
    This field handles the configuration for picker caching.
    By default it is a table, with default values (more below).
    To disable caching, set it to false.

    Caching preserves all previous multi selections and results and
    therefore may result in slowdown or increased RAM occupation
    if too many pickers (`cache_picker.num_pickers`) or entries
    ('cache_picker.limit_entries`) are cached.

    Fields:
      - num_pickers:      The number of pickers to be cached.
                          Set to -1 to preserve all pickers of your session.
                          If passed to a picker, the cached pickers with
                          indices larger than `cache_picker.num_pickers` will
                          be cleared.
                          Default: 1
      - limit_entries:    The amount of entries that will be written in the
                          Default: 1000
    ]]
)

append(
  "preview",
  {
    check_mime_type = true,
    filesize_limit = 25,
    timeout = 250,
    treesitter = true,
    msg_bg_fillchar = "╱",
  },
  [[
    This field handles the global configuration for previewers.
    By default it is a table, with default values (more below).
    To disable previewing, set it to false. If you have disabled previewers
    globally, but want to opt in to previewing for single pickers, you will have to
    pass `preview = true` or `preview = {...}` (your config) to the `opts` of
    your picker.

    Fields:
      - check_mime_type:  Use `file` if available to try to infer whether the
                          file to preview is a binary if plenary's
                          filetype detection fails.
                          Windows users get `file` from:
                          https://github.com/julian-r/file-windows
                          Set to false to attempt to preview any mime type.
                          Default: true
      - filesize_limit:   The maximum file size in MB attempted to be previewed.
                          Set to false to attempt to preview any file size.
                          Default: 25
      - timeout:          Timeout the previewer if the preview did not
                          complete within `timeout` milliseconds.
                          Set to false to not timeout preview.
                          Default: 250
      - hook(s):          Function(s) that takes `(filepath, bufnr, opts)`, where opts
                          exposes winid and ft (filetype).
                          Available hooks (in order of priority):
                          {filetype, mime, filesize, timeout}_hook
                          Important: the filetype_hook must return true or false
                          to indicate whether to continue (true) previewing or not (false),
                          respectively.
                          Two examples:
                          local putils = require("telescope.previewers.utils")
                          ... -- preview is called in telescope.setup { ... }
                            preview = {
                              -- 1) Do not show previewer for certain files
                              filetype_hook = function(filepath, bufnr, opts)
                                -- you could analogously check opts.ft for filetypes
                                local excluded = vim.tbl_filter(function(ending)
                                  return filepath:match(ending)
                                end, {
                                  ".*%.csv",
                                  ".*%.toml",
                                })
                                if not vim.tbl_isempty(excluded) then
                                  putils.set_preview_message(
                                    bufnr,
                                    opts.winid,
                                    string.format("I don't like %s files!",
                                    excluded[1]:sub(5, -1))
                                  )
                                  return false
                                end
                                return true
                              end,
                              -- 2) Truncate lines to preview window for too large files
                              filesize_hook = function(filepath, bufnr, opts)
                                local path = require("plenary.path"):new(filepath)
                                -- opts exposes winid
                                local height = vim.api.nvim_win_get_height(opts.winid)
                                local lines = vim.split(path:head(height), "[\r]?\n")
                                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
                              end,
                            }
                          The configuration recipes for relevant examples.
                          Note: if plenary does not recognize your filetype yet --
                          1) Please consider contributing to:
                             $PLENARY_REPO/data/plenary/filetypes/builtin.lua
                          2) Register your filetype locally as per link
                             https://github.com/nvim-lua/plenary.nvim#plenaryfiletype
                          Default: nil
      - treesitter:       Determines whether the previewer performs treesitter
                          highlighting, which falls back to regex-based highlighting.
                          `true`: treesitter highlighting for all available filetypes
                          `false`: regex-based highlighting for all filetypes
                          `table`: table of filetypes for which to attach treesitter
                          highlighting
                          Default: true
      - msg_bg_fillchar:  Character to fill background of unpreviewable buffers with
                          Default: "╱"
    ]]
)

append(
  "vimgrep_arguments",
  { "rg", "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
  [[
    Defines the command that will be used for `live_grep` and `grep_string`
    pickers.
    Hint: Make sure that color is currently set to `never` because we do
    not yet interpret color codes
    Hint 2: Make sure that these options are in your changes arguments:
      "--no-heading", "--with-filename", "--line-number", "--column"
    because we need them so the ripgrep output is in the correct format.

    Default: {
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case"
    }]]
)

append(
  "use_less",
  true,
  [[
  Boolean if less should be enabled in term_previewer (deprecated and
  currently no longer used in the builtin pickers).

  Default: true]]
)

append(
  "set_env",
  nil,
  [[
  Set an environment for term_previewer. A table of key values:
  Example: { COLORTERM = "truecolor", ... }
  Hint: Empty table is not allowed.

  Default: nil]]
)

append(
  "color_devicons",
  true,
  [[
  Boolean if devicons should be enabled or not.
  Hint: Coloring only works if |termguicolors| is enabled.

  Default: true]]
)

append(
  "mappings",
  {},
  [[
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


  otherwise, just set the mapping to the function that you want it to
  be.

      ...,
      ["<C-i>"] = require('telescope.actions').select_default,
      ...,

  If the function you want is part of `telescope.actions`, then you can
  simply give a string.
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
  ]]
)

append(
  "default_mappings",
  nil,
  [[
  Not recommended to use except for advanced users.

  Will allow you to completely remove all of telescope's default maps
  and use your own.
  ]]
)

append(
  "file_sorter",
  sorters.get_fzy_sorter,
  [[
  A function pointer that specifies the file_sorter. This sorter will
  be used for find_files, git_files and similar.
  Hint: If you load a native sorter, you dont need to change this value,
  the native sorter will override it anyway.

  Default: require("telescope.sorters").get_fzy_sorter]]
)

append(
  "generic_sorter",
  sorters.get_fzy_sorter,
  [[
  A function pointer to the generic sorter. The sorter that should be
  used for everything that is not a file.
  Hint: If you load a native sorter, you dont need to change this value,
  the native sorter will override it anyway.

  Default: require("telescope.sorters").get_fzy_sorter]]
)

--TODO(conni2461): Why is this even configurable???
append(
  "prefilter_sorter",
  sorters.prefilter,
  [[
  This points to a wrapper sorter around the generic_sorter that is able
  to do prefiltering.
  Its usually used for lsp_*_symbols and lsp_*_diagnostics

  Default: require("telescope.sorters").prefilter]]
)

append(
  "file_ignore_patterns",
  nil,
  [[
  A table of lua regex that define the files that should be ignored.
  Example: { "^scratch/" } -- ignore all files in scratch directory
  Example: { "%.npz" } -- ignore all npz files
  See: https://www.lua.org/manual/5.1/manual.html#5.4.1 for more
  information about lua regex

  Default: nil]]
)

append(
  "file_previewer",
  function(...)
    return require("telescope.previewers").vim_buffer_cat.new(...)
  end,
  [[
    Function pointer to the default file_previewer. It is mostly used
    for find_files, git_files and similar.
    You can change this function pointer to either use your own
    previewer or use the command-line program bat as the previewer:
      require("telescope.previewers").cat.new

    Default: require("telescope.previewers").vim_buffer_cat.new]]
)

append(
  "grep_previewer",
  function(...)
    return require("telescope.previewers").vim_buffer_vimgrep.new(...)
  end,
  [[
    Function pointer to the default vim_grep previewer. It is mostly
    used for live_grep, grep_string and similar.
    You can change this function pointer to either use your own
    previewer or use the command-line program bat as the previewer:
      require("telescope.previewers").vimgrep.new

    Default: require("telescope.previewers").vim_buffer_vimgrep.new]]
)

append(
  "qflist_previewer",
  function(...)
    return require("telescope.previewers").vim_buffer_qflist.new(...)
  end,
  [[
    Function pointer to the default qflist previewer. It is mostly
    used for qflist, loclist and lsp.
    You can change this function pointer to either use your own
    previewer or use the command-line program bat as the previewer:
      require("telescope.previewers").qflist.new

    Default: require("telescope.previewers").vim_buffer_vimgrep.new]]
)

append(
  "buffer_previewer_maker",
  function(...)
    return require("telescope.previewers").buffer_previewer_maker(...)
  end,
  [[
    Developer option that defines the underlining functionality
    of the buffer previewer.
    For interesting configuration examples take a look at
    https://github.com/nvim-telescope/telescope.nvim/wiki/Configuration-Recipes

    Default: require("telescope.previewers").buffer_previewer_maker]]
)

-- @param user_defaults table: a table where keys are the names of options,
--    and values are the ones the user wants
-- @param tele_defaults table: (optional) a table containing all of the defaults
--    for telescope [defaults to `telescope_defaults`]
function config.set_defaults(user_defaults, tele_defaults)
  user_defaults = if_nil(user_defaults, {})
  tele_defaults = if_nil(tele_defaults, telescope_defaults)

  -- Check if using layout keywords outside of `layout_config`
  deprecated.picker_window_options(user_defaults)

  -- Check if using `layout_defaults` instead of `layout_config`
  user_defaults = deprecated.layout_configuration(user_defaults)

  local function get(name, default_val)
    if name == "layout_config" then
      return smarter_depth_2_extend(
        if_nil(user_defaults[name], {}),
        vim.tbl_deep_extend("keep", if_nil(config.values[name], {}), if_nil(default_val, {}))
      )
    end
    if name == "history" or name == "cache_picker" or name == "preview" then
      if user_defaults[name] == false or config.values[name] == false then
        return false
      end

      return smarter_depth_2_extend(
        if_nil(user_defaults[name], {}),
        vim.tbl_deep_extend("keep", if_nil(config.values[name], {}), if_nil(default_val, {}))
      )
    end
    return first_non_null(user_defaults[name], config.values[name], default_val)
  end

  local function set(name, default_val, description)
    assert(description, "Config values must always have a description")

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
