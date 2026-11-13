require "telescope"

local fn = vim.fn
local api = vim.api

local _async = require "telescope._async"
local ui = require "telescope.pickers.ui"

local actions = require "telescope.actions"
local config = require "telescope.config"
local debounce = require "telescope.debounce"
local log = require "telescope.log"
local mappings = require "telescope.mappings"
local state = require "telescope.state"
local utils = require "telescope.utils"

local entry_display = require "telescope.pickers.entry_display"
local p_highlighter = require "telescope.pickers.highlights"
local p_scroller = require "telescope.pickers.scroller"
local p_window = require "telescope.pickers.window"
local Layout = require "telescope.pickers.layout"

local EntryManager = require "telescope.entry_manager"
local MultiSelect = require "telescope.pickers.multi"

local ns_telescope_matching = api.nvim_create_namespace "telescope_matching"
local ns_telescope_prompt = api.nvim_create_namespace "telescope_prompt"
local ns_telescope_prompt_prefix = api.nvim_create_namespace "telescope_prompt_prefix"

-- while results come in, draw them at most this often (ms)
local DRAW_INTERVAL = 50

-- preallocating table constructor (LuaJIT), for the narrowing match lists
local ok_new_tab, new_tab = pcall(require, "table.new")
if not ok_new_tab then
  new_tab = function()
    return {}
  end
end

-- Window options produced by layout strategies and passed to `telescope.pickers.ui`.
---@class telescope_popup_options
---@field line integer: 1-based screen row of the content (0 or nil: centered)
---@field col integer: 1-based screen column of the content (0 or nil: centered)
---@field width integer
---@field height integer
---@field minheight integer|nil
---@field border boolean|table<1|2|3|4, integer>|nil: thickness above, right, below, left
---@field borderchars table<integer, string>|nil: top, right, bottom, left, topleft, topright, botright, botleft
---@field title string|{ pos: "NW"|"N"|"NE"|"SW"|"S"|"SE", text: string }[]|nil
---@field highlight string|nil
---@field borderhighlight string|nil
---@field titlehighlight string|nil
---@field enter boolean|nil: enter the window (default true)
---@field focusable boolean|nil
---@field zindex integer|nil

-- Create three windows: prompt, results and (optionally) preview.
--
---@param picker Picker
local function default_create_layout(picker)
  -- Joined layouts let the prompt's border overlap those of the results and preview windows, whose
  -- border characters (e.g. `├`, `┤`) must stay visible, also after the prompt (on top once entered)
  -- gets focus again: hence the different `zindex`.
  local roles = {
    results = { focusable = true, zindex = 52, hl = "TelescopeResults" },
    preview = { focusable = true, zindex = 51, hl = "TelescopePreview" },
    prompt = { focusable = false, zindex = 50, hl = "TelescopePrompt" },
  }

  local function window_options()
    local line_count = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus ~= 0 and 1 or 0)
    return picker:get_window_options(vim.o.columns, line_count)
  end

  ---@param self TelescopeLayout
  local function create_window(self, name, opts)
    local role = roles[name]
    opts.focusable = role.focusable
    opts.zindex = role.zindex
    opts.highlight = role.hl .. "Normal"
    opts.borderhighlight = role.hl .. "Border"
    opts.titlehighlight = role.hl .. "Title"
    local win, border = picker:_create_window(nil, opts)
    self[name] = Layout.Window { winid = win, bufnr = api.nvim_win_get_buf(win), border = border }
    return win
  end

  local layout = Layout {
    picker = picker,
    ---@param self TelescopeLayout
    mount = function(self)
      local popup_opts = window_options()
      -- the prompt comes last: it is entered
      for _, name in ipairs { "results", "preview", "prompt" } do
        if popup_opts[name] then
          create_window(self, name, popup_opts[name])
        end
      end
    end,
    ---@param self TelescopeLayout
    unmount = function(self)
      utils.win_delete("results_win", self.results.winid, true, true)
      if self.preview then
        utils.win_delete("preview_win", self.preview.winid, true, true)
      end

      -- we cant use win_delete. We first need to close and then delete the buffer
      if api.nvim_win_is_valid(self.prompt.winid) then
        api.nvim_win_close(self.prompt.winid, true)
      end
      vim.schedule(function()
        utils.buf_delete(self.prompt.bufnr)
      end)
    end,
    ---@param self TelescopeLayout
    update = function(self)
      local popup_opts = window_options()
      local preview_win = self.preview and self.preview.winid
      if popup_opts.preview and not preview_win then
        preview_win = create_window(self, "preview", popup_opts.preview)
        if picker.previewer and picker.previewer.state and picker.previewer.state.winid then
          picker.previewer.state.winid = preview_win
        end
      elseif popup_opts.preview then
        ui.move(preview_win, popup_opts.preview)
      elseif preview_win then
        utils.win_delete("preview_win", preview_win, true)
        self.preview = nil
      end
      ui.move(self.prompt.winid, popup_opts.prompt)
      ui.move(self.results.winid, popup_opts.results)
    end,
  }

  return layout
end

local pickers = {}

---@class Picker
--- Picker is the main UI that shows up to interact w/ your results.
-- Takes a filter & a previewer
local Picker = {}
Picker.__index = Picker

--- Create new picker
function Picker:new(opts)
  opts = opts or {}

  if opts.layout_strategy and opts.get_window_options then
    error "layout_strategy and get_window_options are not compatible keys"
  end

  if fn.win_gettype() == "command" then
    error "Can't open telescope from command-line window. See E11"
  end

  -- We need to clear at the beginning not on close because after close we can still have select:post
  -- etc ...
  require("telescope.actions.mt").clear_all()

  local layout_strategy = vim.nonnil(opts.layout_strategy, config.values.layout_strategy)
  local winblend =
    vim.nonnil(opts.winblend, type(opts.window) == "table" and opts.window.winblend or config.values.winblend)
  if type(winblend) == "function" then
    winblend = winblend()
  end

  local obj = setmetatable({
    prompt_title = vim.nonnil(opts.prompt_title, config.values.prompt_title),
    results_title = vim.nonnil(opts.results_title, config.values.results_title),
    -- either whats passed in by the user or whats defined by the previewer
    preview_title = opts.preview_title,

    prompt_prefix = vim.nonnil(opts.prompt_prefix, config.values.prompt_prefix),
    wrap_results = vim.nonnil(opts.wrap_results, config.values.wrap_results),
    selection_caret = vim.nonnil(opts.selection_caret, config.values.selection_caret),
    entry_prefix = vim.nonnil(opts.entry_prefix, config.values.entry_prefix),
    multi_icon = vim.nonnil(opts.multi_icon, config.values.multi_icon),

    initial_mode = vim.nonnil(opts.initial_mode, config.values.initial_mode),
    _original_mode = api.nvim_get_mode().mode,
    debounce = vim.nonnil(tonumber(opts.debounce), nil),

    _finder_attached = true,
    default_text = opts.default_text,
    get_status_text = vim.nonnil(opts.get_status_text, config.values.get_status_text),
    _on_input_filter_cb = opts.on_input_filter_cb or function() end,

    finder = assert(opts.finder, "Finder is required."),
    sorter = opts.sorter or require("telescope.sorters").empty(),

    all_previewers = opts.previewer,
    current_previewer_index = opts.current_previewer_index or 1,

    default_selection_index = opts.default_selection_index,

    get_selection_window = vim.nonnil(opts.get_selection_window, config.values.get_selection_window),

    cwd = opts.cwd,

    _completion_callbacks = type(opts._completion_callbacks) == "table" and opts._completion_callbacks or {},
    manager = (type(opts.manager) == "table" and getmetatable(opts.manager) == EntryManager) and opts.manager,
    _multi = (type(opts._multi) == "table" and getmetatable(opts._multi) == getmetatable(MultiSelect:new()))
        and opts._multi
      or MultiSelect:new(),

    track = vim.nonnil(opts.track, false),
    stats = {},

    attach_mappings = opts.attach_mappings,
    on_close = opts.on_close,
    file_ignore_patterns = vim.nonnil(opts.file_ignore_patterns, config.values.file_ignore_patterns),

    scroll_strategy = vim.nonnil(opts.scroll_strategy, config.values.scroll_strategy),
    sorting_strategy = vim.nonnil(opts.sorting_strategy, config.values.sorting_strategy),
    tiebreak = vim.nonnil(opts.tiebreak, config.values.tiebreak),
    selection_strategy = vim.nonnil(opts.selection_strategy, config.values.selection_strategy),

    push_cursor_on_edit = vim.nonnil(opts.push_cursor_on_edit, false),
    push_tagstack_on_edit = vim.nonnil(opts.push_tagstack_on_edit, false),

    layout_strategy = layout_strategy,
    layout_config = config.smarter_depth_2_extend(opts.layout_config or {}, config.values.layout_config or {}),

    __cycle_layout_list = vim.nonnil(opts.cycle_layout_list, config.values.cycle_layout_list),

    window = {
      winblend = winblend,
      border = vim.nonnil(opts.border, type(opts.window) == "table" and opts.window.border or config.values.border),
      borderchars = vim.nonnil(
        opts.borderchars,
        type(opts.window) == "table" and opts.window.borderchars or config.values.borderchars
      ),
    },

    cache_picker = config.resolve_table_opts(opts.cache_picker, vim.deepcopy(config.values.cache_picker)),

    __scrolling_limit = tonumber(vim.nonnil(opts.temp__scrolling_limit, 250)),

    __locations_input = vim.nonnil(opts.__locations_input, false),
  }, self)

  obj.create_layout = opts.create_layout or config.values.create_layout or default_create_layout
  obj.get_window_options = opts.get_window_options or p_window.get_window_options

  if obj.all_previewers ~= nil and obj.all_previewers ~= false then
    if obj.all_previewers[1] == nil then
      obj.all_previewers = { obj.all_previewers }
    end
    obj.previewer = obj.all_previewers[obj.current_previewer_index]
    if
      obj.preview_title == nil
      or #obj.all_previewers > 1
      or opts.resumed_picker and opts.fix_preview_title ~= true
    then
      obj.preview_title = obj.previewer:title(nil, config.values.dynamic_preview_title)
    else
      obj.fix_preview_title = true
    end
  else
    obj.previewer = false
  end

  local __hide_previewer = opts.__hide_previewer
  if __hide_previewer then
    obj.hidden_previewer = obj.previewer
    obj.previewer = nil
  else
    obj.hidden_previewer = nil
  end

  obj.scroller = p_scroller.create(obj.scroll_strategy, obj.sorting_strategy)

  obj.highlighter = p_highlighter.new(obj)

  if opts.on_complete then
    for _, on_complete_item in ipairs(opts.on_complete) do
      obj:register_completion_callback(on_complete_item)
    end
  end

  return obj
end

--- Take an index and get a row.
---@note: Rows are 0-indexed, and `index` is 1 indexed (table index)
---@param index number: the index in line_manager
---@return number: the row for the picker to display in
function Picker:get_row(index)
  if self.sorting_strategy == "ascending" then
    return index - 1
  else
    return self.max_results - index
  end
end

--- Take a row and get an index
---@note: Rows are 0-indexed, and `index` is 1 indexed (table index)
---@param row number: The row being displayed
---@return number: The index in line_manager
function Picker:get_index(row)
  if self.sorting_strategy == "ascending" then
    return row + 1
  else
    return self.max_results - row
  end
end

--- Get the row number of the "best" entry
---@return number: the number of the "reset" row
function Picker:get_reset_row()
  if self.sorting_strategy == "ascending" then
    return 0
  else
    return self.max_results - 1
  end
end

--- Check if the picker is no longer in use
---@return boolean|nil: `true` if picker is closed, `nil` otherwise
function Picker:is_done()
  if not self.manager then
    return true
  end
end

--- Clear rows that are after the final remaining entry
---@note: useful when number of remaining results is narrowed down
---@param results_bufnr number: the buffer number of the results buffer
function Picker:clear_extra_rows(results_bufnr)
  if self:is_done() then
    log.trace "Not clearing due to being already complete"
    return
  end

  if not api.nvim_buf_is_valid(results_bufnr) then
    log.debug("Invalid results_bufnr for clearing:", results_bufnr)
    return
  end

  local worst_line, ok, msg
  if self.sorting_strategy == "ascending" then
    local num_results = self.manager:num_results()
    worst_line = math.min(num_results, self.max_results)
    ok, msg = pcall(api.nvim_buf_set_lines, results_bufnr, worst_line, -1, false, {})
  else
    worst_line = self:get_row(self.manager:num_results())
    if worst_line <= 0 then
      return
    end

    local empty_lines = utils.repeated_table(worst_line, "")
    ok, msg = pcall(api.nvim_buf_set_lines, results_bufnr, 0, worst_line, false, empty_lines)
  end

  if not ok then
    log.debug("Failed to set lines:", msg)
  end

  log.trace("Clearing:", worst_line)
end

--- Highlight the entry corresponding to the given row
---@param results_bufnr number: the buffer number of the results buffer
---@param prompt table: table with information about the prompt buffer
---@param display string: the text corresponding to the given row
---@param row number: the number of the chosen row
function Picker:highlight_one_row(results_bufnr, prompt, display, row)
  if not self.sorter.highlighter then
    return
  end

  local highlights = self.sorter:highlighter(prompt, display)

  if highlights then
    for _, hl in ipairs(highlights) do
      local highlight, start, finish
      if type(hl) == "table" then
        highlight = hl.highlight or "TelescopeMatching"
        start = hl.start
        finish = hl.finish or hl.start
      elseif type(hl) == "number" then
        highlight = "TelescopeMatching"
        start = hl
        finish = hl
      else
        error "Invalid higlighter fn"
      end

      -- extmark instead of `vim.hl.range()`, which is much slower (runs for every displayed row)
      api.nvim_buf_set_extmark(results_bufnr, ns_telescope_matching, row, start - 1, {
        end_col = finish,
        hl_group = highlight,
        priority = vim.hl.priorities.user,
        strict = false,
      })
    end
  end

  local entry = self.manager:get_entry(self:get_index(row))
  self.highlighter:hi_multiselect(row, self:is_multi_selected(entry))
end

--- Check if the given row number can be selected
---@param row number: the number of the chosen row in the results buffer
---@return boolean
function Picker:can_select_row(row)
  if self.sorting_strategy == "ascending" then
    return row <= self.manager:num_results() and row < self.max_results
  else
    return row >= 0 and row <= self.max_results and row >= self.max_results - self.manager:num_results()
  end
end

--- A helper function for creating each of the windows in a picker
---@param bufnr integer?: the buffer to show in the window (nil: a new scratch buffer)
---@param popup_opts table: options to pass to `ui.create`
---@return integer win
---@return table|nil border
function Picker:_create_window(bufnr, popup_opts)
  local win, border = ui.create(bufnr, popup_opts)
  vim.wo[win].winblend = self.window.winblend
  return win, border
end

--- Opens the given picker for the user to interact with
---@note: this is the main function for pickers, as it actually creates the interface for users
function Picker:find()
  self:close_existing_pickers()
  self:reset_selection()

  self.__original_mousemoveevent = vim.o.mousemoveevent
  vim.o.mousemoveevent = true

  self.original_bufnr = api.nvim_get_current_buf()
  self.original_win_id = api.nvim_get_current_win()
  self.original_tabpage = api.nvim_get_current_tabpage()
  _, self.original_cword = pcall(fn.expand, "<cword>")
  _, self.original_cWORD = pcall(fn.expand, "<cWORD>")
  _, self.original_cfile = pcall(fn.expand, "<cfile>")
  _, self.original_cline = pcall(api.nvim_get_current_line)
  _, self.original_cline = pcall(vim.trim, self.original_cline)

  -- User autocmd run it before create Telescope window
  api.nvim_exec_autocmds("User", { pattern = "TelescopeFindPre" })

  local layout = self:create_layout()
  layout:mount()

  self.layout = layout
  self.prompt_win, self.prompt_bufnr, self.prompt_border =
    layout.prompt.winid, layout.prompt.bufnr, layout.prompt.border
  self.results_win, self.results_bufnr, self.results_border =
    layout.results.winid, layout.results.bufnr, layout.results.border
  if layout.preview then
    self.preview_win, self.preview_bufnr, self.preview_border =
      layout.preview.winid, layout.preview.bufnr, layout.preview.border
  else
    self.preview_win, self.preview_bufnr, self.preview_border = nil, nil, nil
  end

  pcall(api.nvim_set_option_value, "tabstop", 1, { buf = self.results_bufnr }) -- #1834
  pcall(api.nvim_set_option_value, "tabstop", 1, { buf = self.prompt_bufnr }) -- #1834
  vim.bo[self.prompt_bufnr].buftype = "prompt"
  vim.wo[self.results_win].wrap = self.wrap_results
  vim.wo[self.prompt_win].wrap = true
  if self.preview_win then
    vim.wo[self.preview_win].wrap = true
  end

  -- Prompt prefix
  local prompt_prefix = self.prompt_prefix
  fn.prompt_setprompt(self.prompt_bufnr, prompt_prefix)
  self:_reset_prefix_color(self._current_prefix_hl_group)

  -- at most this many results are shown (undocumented option `temp__scrolling_limit`, default 250)
  self.max_results = self.__scrolling_limit

  api.nvim_buf_set_lines(self.results_bufnr, 0, self.max_results, false, utils.repeated_table(self.max_results, ""))

  local status_updater = self:get_status_updater(self.prompt_win, self.prompt_bufnr)
  local debounced_status = debounce.throttle_leading(status_updater, 50)

  -- a prompt change (or a refresh) cancels the running find and wakes the main loop
  local send, wait = _async.signal()
  self._on_lines = function()
    local find = self._find
    if find then
      self._find = nil
      find.matches.stale = true -- for finders that process results outside the find's task
      find.task:close()
    end
    send()
  end

  if self.default_text then
    self:set_prompt(self.default_text)
  end

  if vim.tbl_contains({ "insert", "normal" }, self.initial_mode) then
    local mode = fn.mode()
    local keys
    if self.initial_mode == "normal" then
      -- n: A<ESC> makes sure cursor is at always at end of prompt w/o default_text
      keys = mode ~= "n" and "<ESC>A<ESC>" or "A<ESC>"
    else
      -- always fully retrigger insert mode: required for going from one picker to next
      keys = mode ~= "n" and "<ESC>A" or "A"
    end
    api.nvim_feedkeys(api.nvim_replace_termcodes(keys, true, false, true), "ni", true)
  else
    utils.notify("pickers.find", {
      msg = "`initial_mode` should be one of ['normal', 'insert'] but passed " .. self.initial_mode,
      level = "ERROR",
    })
  end

  local main_loop = function()
    self.sorter:_init()

    -- Do filetype last, so that users can register at the last second.
    pcall(api.nvim_set_option_value, "filetype", "TelescopePrompt", { buf = self.prompt_bufnr })
    pcall(api.nvim_set_option_value, "filetype", "TelescopeResults", { buf = self.results_bufnr })

    _async.yield()

    while true do
      -- Wait for the next input
      wait()
      _async.yield()

      self:_reset_track()

      if not api.nvim_buf_is_valid(self.prompt_bufnr) then
        log.debug("ON_LINES: Invalid prompt_bufnr", self.prompt_bufnr)
        return
      end

      -- we kinda always wanna reset the color, because of `cc` and `dd` commands,
      -- which also delete the prefix and after prefix deletion we need to reapply highlighting
      self:_reset_prefix_color(self._current_prefix_hl_group)

      local start_time = vim.uv.hrtime()

      local prompt = self:_get_next_filtered_prompt()
      state.set_global_key("current_line", prompt)

      if self.__locations_input == true then
        local filename, line_number, column_number = utils.__separate_file_path_location(prompt)

        if line_number or column_number then
          state.set_global_key("prompt_location", { row = line_number, col = column_number })
        elseif state.get_global_key "prompt_location" then
          state.set_global_key("prompt_location", nil)
        end

        -- it is important to continue behaving as if there is no location in prompt
        prompt = filename
      elseif state.get_global_key "prompt_location" then
        -- in case new picker that does not support locations is opened clear the location
        state.set_global_key("prompt_location", nil)
      end

      if self.cache_picker == false or self.cache_picker.is_cached ~= true then
        local discarded = self.sorter._discard_state and self.sorter._discard_state.filtered
        self.sorter:_start(prompt)
        local narrowable = self:_narrowable()
        local candidates = narrowable and self:_narrowed_candidates(discarded)
        self.manager = EntryManager:new(self.max_results, self._results_changed)

        -- the matches of this prompt, in finder order (see `_narrowed_candidates`), recorded in the
        -- one of two reused arrays that the previous matches don't use (no new array per prompt)
        local matches = { finder = self.finder, n = 0 }
        if narrowable then
          local prev, lists = self._matches, self._match_lists or {}
          self._match_lists = lists
          local k = (prev and prev.list == lists[1]) and 2 or 1
          if not lists[k] then
            lists[k] = new_tab(candidates and candidates.n or 0, 0)
          end
          matches.list = lists[k]
        end
        self._matches = matches
        self:_reset_highlights()
        local process_result = self:get_result_processor(prompt, debounced_status)
        local completor = self:get_result_completor(self.results_bufnr, prompt, status_updater)
        local process_complete = function()
          if not matches.stale then
            matches.complete, matches.processed = true, self.stats.processed
            completor()
          end
        end

        -- the find is a child task, closed by the next prompt change (see `self._on_lines`)
        local task = vim.async.run(function()
          if candidates then
            self:_process_candidates(candidates, process_result, process_complete)
          else
            self.finder(prompt, process_result, process_complete)
          end
        end)
        self._find = { task = task, matches = matches }
        local ok, msg = vim.async.pawait(task)
        self._find = nil

        if not ok and msg ~= "closed" then
          utils.notify("pickers.find", { msg = "Finder failed: " .. tostring(msg), level = "WARN" })
        end

        local diff_time = (vim.uv.hrtime() - start_time) / 1e6
        if self.debounce and diff_time < self.debounce then
          vim.async.sleep(self.debounce - diff_time)
        end
      else
        self:_resume_picker()
      end
    end
  end

  -- Register attach
  api.nvim_buf_attach(self.prompt_bufnr, false, {
    on_lines = function()
      if self._finder_attached then
        status_updater { completed = false }
        self._on_lines()
      end
    end,

    on_detach = function()
      self:_detach()
    end,
  })

  api.nvim_create_augroup("PickerInsert", {})
  -- also fires when the prompt window is left or closed (the prompt buffer is shown in no other
  -- window), so no WinLeave needed
  api.nvim_create_autocmd("BufLeave", {
    buf = self.prompt_bufnr,
    group = "PickerInsert",
    nested = true,
    once = true,
    callback = function()
      require("telescope.pickers").on_close_prompt(self.prompt_bufnr)
    end,
  })
  api.nvim_create_autocmd("VimResized", {
    buf = self.prompt_bufnr,
    group = "PickerInsert",
    nested = true,
    callback = function()
      require("telescope.pickers").on_resize_window(self.prompt_bufnr)
    end,
  })

  state.set_status(
    self.prompt_bufnr,
    setmetatable({
      layout = layout,
      picker = self,

      -- compatibility
      prompt_bufnr = self.prompt_bufnr,
      prompt_win = self.prompt_win,
      results_bufnr = self.results_bufnr,
      results_win = self.results_win,
      preview_bufnr = self.preview_bufnr,
      preview_win = self.preview_win,
    }, {
      __mode = "kv",
    })
  )

  mappings.apply_keymap(self.prompt_bufnr, self.attach_mappings, config.values.mappings)

  send()
  -- closed in `_detach`; report other errors
  self._main_task = vim.async.run(main_loop)
  self._main_task:on_complete(function(err)
    if err ~= nil and err ~= "closed" then
      error(err, 0)
    end
  end)
end

--- A helper function to update picker windows when layout options are changed
function Picker:recalculate_layout()
  local status = state.get_status(self.prompt_bufnr)

  status.layout:update()

  local layout = status.layout
  self.prompt_win, self.prompt_bufnr, self.prompt_border =
    layout.prompt.winid, layout.prompt.bufnr, layout.prompt.border
  self.results_win, self.results_bufnr, self.results_border =
    layout.results.winid, layout.results.bufnr, layout.results.border
  if layout.preview then
    self.preview_win, self.preview_bufnr, self.preview_border =
      layout.preview.winid, layout.preview.bufnr, layout.preview.border
  else
    self.preview_win, self.preview_bufnr, self.preview_border = nil, nil, nil
  end

  -- Temporarily disabled: Draw the screen ASAP. This makes things feel speedier.
  -- vim.cmd [[redraw]]

  -- self.max_results = popup_opts.results.height
end

local update_scroll = function(win, oldinfo, oldcursor, strategy, buf_maxline)
  if strategy == "ascending" then
    api.nvim_win_set_cursor(win, { buf_maxline, 0 })
    api.nvim_win_set_cursor(win, { oldinfo.topline, 0 })
    api.nvim_win_set_cursor(win, oldcursor)
  elseif strategy == "descending" then
    api.nvim_win_set_cursor(win, { 1, 0 })
    api.nvim_win_set_cursor(win, { oldinfo.botline, 0 })
    api.nvim_win_set_cursor(win, oldcursor)
  else
    error(debug.traceback("Unknown sorting strategy: " .. (strategy or "")))
  end
end

--- A wrapper for `Picker:recalculate_layout()` that also handles maintaining cursor position
function Picker:full_layout_update()
  local oldinfo = fn.getwininfo(self.results_win)[1]
  local oldcursor = api.nvim_win_get_cursor(self.results_win)
  self:recalculate_layout()
  self:refresh_previewer()

  -- update scrolled position
  local buf_maxline = #api.nvim_buf_get_lines(self.results_bufnr, 0, -1, false)
  update_scroll(self.results_win, oldinfo, oldcursor, self.sorting_strategy, buf_maxline)
end

--- A simple interface to remove an entry from the results window without
--- closing telescope. This either deletes the current selection or all the
--- selections made using multi-select. It can be used to define actions
--- such as deleting buffers or files.
---
--- Example usage:
--- ```lua
--- actions.delete_something = function(prompt_bufnr)
---    local current_picker = action_state.get_current_picker(prompt_bufnr)
---    current_picker:delete_selection(function(selection)
---      -- delete the selection outside of telescope
---    end)
--- end
--- ```
---
--- Example usage in telescope:
---   - `actions.delete_buffer()`
---@param delete_cb function: called for each selection fn(s) -> bool|nil (true|nil removes the entry from the results)
function Picker:delete_selection(delete_cb)
  vim.validate("delete_cb", delete_cb, "function")

  local original_selection_strategy = self.selection_strategy
  self.selection_strategy = "row"

  local delete_selections = self._multi:get()
  local used_multi_select = true
  if vim.tbl_isempty(delete_selections) then
    table.insert(delete_selections, self:get_selection())
    used_multi_select = false
  end

  local selection_index = {}
  for result_index, result_entry in pairs(self.finder.results) do
    if vim.tbl_contains(delete_selections, result_entry) then
      table.insert(selection_index, result_index)
    end
  end

  -- Sort in reverse order as removing an entry from the table shifts down the
  -- other elements to close the hole.
  table.sort(selection_index, function(x, y)
    return x > y
  end)
  for _, index in ipairs(selection_index) do
    local delete_cb_return = delete_cb(self.finder.results[index])
    if delete_cb_return == nil or delete_cb_return == true then
      table.remove(self.finder.results, index)
    end
  end

  if used_multi_select then
    self._multi = MultiSelect:new()
  end

  self:refresh()
  vim.defer_fn(function()
    self.selection_strategy = original_selection_strategy
  end, 50)
end

---@param text string text to set as prompt
---@param reset boolean? whether to replace prompt with text entirely or just append
function Picker:set_prompt(text, reset)
  reset = vim.nonnil(reset, true)
  if not reset then
    text = self:_get_prompt() .. text
  end
  self:reset_prompt(text)
end

--- Closes the windows for the prompt, results and preview
---@param status table: table containing information on the picker
--- and associated windows. Generally obtained from `state.get_status`
function Picker.close_windows(status)
  local prompt_bufnr = status.layout.prompt.bufnr
  status.layout:unmount()
  state.clear_status(prompt_bufnr)
end

--- Get the entry table of the current selection
---@return table
function Picker:get_selection()
  return self._selection_entry
end

--- Get the row number of the current selection
---@return number
function Picker:get_selection_row()
  if self._selection_row then
    -- If the current row is no longer selectable than reduce it to num_results - 1, so the next selectable row.
    -- This makes selection_strategy `row` work much better if the selected row is no longer part of the output.
    if self.selection_strategy == "row" then
      local num_results = self.manager:num_results()
      if self.sorting_strategy == "ascending" then
        if self._selection_row >= num_results then
          return num_results - 1
        end
      else
        local max = self.max_results - num_results
        if self._selection_row < max then
          return self.max_results - num_results
        end
      end
    end
    return self._selection_row
  end
  return self:get_reset_row()
end

--- Move the current selection by `change` steps
---@param change number
function Picker:move_selection(change)
  self:set_selection(self:get_selection_row() + change)
end

--- Add the entry of the given row to the multi-select object
---@param row number: the number of the chosen row
function Picker:add_selection(row)
  local entry = self.manager:get_entry(self:get_index(row))
  self._multi:add(entry)

  self:update_prefix(entry, row)
  self:get_status_updater(self.prompt_win, self.prompt_bufnr)()
  self.highlighter:hi_multiselect(row, true)
end

--- Remove the entry of the given row to the multi-select object
---@param row number: the number of the chosen row
function Picker:remove_selection(row)
  local entry = self.manager:get_entry(self:get_index(row))
  self._multi:drop(entry)

  self:update_prefix(entry, row)
  self:get_status_updater(self.prompt_win, self.prompt_bufnr)()
  self.highlighter:hi_multiselect(row, false)
end

--- Check if the given row is in the multi-select object
---@param entry table: table with information about the chosen entry
---@return number: the "count" associated to the entry in the multi-select
--- object (if present), `nil` otherwise
function Picker:is_multi_selected(entry)
  return self._multi:is_selected(entry)
end

--- Get a table containing all of the currently selected entries
---@return table: an integer indexed table of selected entries
function Picker:get_multi_selection()
  return self._multi:get()
end

--- Toggle the given row in and out of the multi-select object.
--- Also updates the highlighting for the given entry
---@param row number: the number of the chosen row
function Picker:toggle_selection(row)
  local entry = self.manager and self.manager:get_entry(self:get_index(row))
  if entry == nil then
    return
  end
  self._multi:toggle(entry)

  self:update_prefix(entry, row)
  self:get_status_updater(self.prompt_win, self.prompt_bufnr)()
  self.highlighter:hi_multiselect(row, self._multi:is_selected(entry))
end

--- Set the current selection to `nil`
---@note: generally used when a picker is first activated with `find()`
function Picker:reset_selection()
  self._selection_entry = nil
  self._selection_row = nil
end

function Picker:_reset_prefix_color(hl_group)
  self._current_prefix_hl_group = hl_group or nil

  if not api.nvim_buf_is_valid(self.prompt_bufnr) then
    return
  end
  api.nvim_buf_clear_namespace(self.prompt_bufnr, ns_telescope_prompt_prefix, 0, -1)
  if self.prompt_prefix ~= "" then
    vim.hl.range(
      self.prompt_bufnr,
      ns_telescope_prompt_prefix,
      self._current_prefix_hl_group or "TelescopePromptPrefix",
      { 0, 0 },
      { 0, #self.prompt_prefix }
    )
  end
end

--- Change the prefix in the prompt to be `new_prefix` and apply `hl_group`
---@param new_prefix string: the string to be used as the new prefix
---@param hl_group string: the name of the chosen highlight
function Picker:change_prompt_prefix(new_prefix, hl_group)
  if not new_prefix then
    return
  end

  if new_prefix ~= "" then
    fn.prompt_setprompt(self.prompt_bufnr, new_prefix)
  else
    api.nvim_buf_set_text(self.prompt_bufnr, 0, 0, 0, #self.prompt_prefix, {})
    vim.bo[self.prompt_bufnr].buftype = ""
  end
  self.prompt_prefix = new_prefix
  self:_reset_prefix_color(hl_group)
end

--- Reset the prompt to the provided `text`
---@param text string
function Picker:reset_prompt(text)
  local prompt_text = self.prompt_prefix .. (text or "")
  api.nvim_buf_set_lines(self.prompt_bufnr, 0, -1, false, { prompt_text })
  self:_reset_prefix_color(self._current_prefix_hl_group)

  if text then
    api.nvim_win_set_cursor(self.prompt_win, { 1, #prompt_text })
  end
end

---@class telescope.picker.refresh.opts
---@field new_prefix? string|table either as string or { new_string, hl_group }
---@field prefix_hl_group? string highlight group of a string `new_prefix`
---@field reset_prompt? boolean whether to reset the prompt
---@field multi? MultiSelect multi-selection to persist upon renewing finder (see telescope/pickers/multi.lua)

---@param finder finder: telescope finder (see telescope/finders.lua)
---@param opts? telescope.picker.refresh.opts: options to pass when refreshing the picker
function Picker:refresh(finder, opts)
  opts = opts or {}
  if opts.new_prefix then
    local new_prefix, hl_group = opts.new_prefix, opts.prefix_hl_group
    if type(new_prefix) == "table" then
      new_prefix, hl_group = new_prefix[1], new_prefix[2]
    end
    self:change_prompt_prefix(new_prefix, hl_group)
  end

  if finder then
    self.finder:close()
    self.finder = finder
    self._multi = vim.nonnil(opts.multi, MultiSelect:new())
  end
  -- the finder's results may have changed (e.g. `delete_selection`): don't narrow
  self._matches = nil

  -- reset already triggers finder loop
  if opts.reset_prompt then
    self:reset_prompt()
  else
    self._on_lines()
  end
end

---Set the selection to the provided `row`
---@param row number
function Picker:set_selection(row)
  if not self.manager then
    return
  end

  row = self.scroller(self.max_results, self.manager:num_results(), row)

  if not self:can_select_row(row) then
    -- If the current selected row exceeds number of currently displayed
    -- elements we have to reset it. Affects sorting_strategy = 'row'.
    if not self:can_select_row(self:get_selection_row()) then
      row = self:get_row(self.manager:num_results())
    else
      log.trace("Cannot select row:", row, self.manager:num_results(), self.max_results)
      return
    end
  end

  local results_bufnr = self.results_bufnr
  if not api.nvim_buf_is_valid(results_bufnr) then
    return
  end

  if row > api.nvim_buf_line_count(results_bufnr) then
    log.debug(
      string.format("Should not be possible to get row this large %s %s", row, api.nvim_buf_line_count(results_bufnr))
    )

    return
  end

  local entry = self.manager:get_entry(self:get_index(row))

  local prompt_location = state.get_global_key "prompt_location"
  if entry and prompt_location then
    entry.lnum = prompt_location.row or 0
    if prompt_location.col and prompt_location.col > 0 then
      entry.col = prompt_location.col
      entry.colend = prompt_location.col + 1
    else
      entry.col = 1 -- we do + 1 here because previewer does -1
      entry.colend = 0
    end
  end

  state.set_global_key("selected_entry", entry)

  if not entry then
    -- also refresh previewer when there is no entry selected, so the preview window is cleared
    self._selection_entry = entry
    self:refresh_previewer()
    return
  end

  local old_entry

  -- entry displays and sorter highlighters are user code: don't let their errors break selection
  local set_ok, set_errmsg = pcall(function()
    local prompt = self:_get_prompt()

    -- Check if previous selection is still visible
    if self._selection_entry and self.manager:find_entry(self._selection_entry) then
      -- Find old selection, and update prefix and highlights
      old_entry = self._selection_entry
      local old_row = self:get_row(self.manager:find_entry(old_entry))

      self._selection_entry = entry

      if old_row >= 0 then
        self:update_prefix(old_entry, old_row)
        self.highlighter:hi_multiselect(old_row, self:is_multi_selected(old_entry))
      end
    else
      self._selection_entry = entry
    end

    local caret = self:update_prefix(entry, row)

    local display, _ = entry_display.resolve(self, entry)
    display = caret .. display

    if not api.nvim_buf_is_valid(results_bufnr) then
      log.debug "Invalid buf somehow..."
      return
    end

    -- don't highlight any whitespace at the end of caret
    self.highlighter:hi_selection(row, caret:match "(.*%S)")
    self.highlighter:hi_sorter(row, prompt, display)

    self.highlighter:hi_multiselect(row, self:is_multi_selected(entry))
  end)

  if not set_ok then
    log.debug(set_errmsg)
    return
  end

  self:refresh_previewer()
  if old_entry == entry and self._selection_row == row then
    return
  end

  self._selection_entry = entry
  self._selection_row = row

  api.nvim_win_set_cursor(self.results_win, { row + 1, 0 })
end

--- Update prefix for entry on a given row
function Picker:update_prefix(entry, row)
  local prefix = function(sel, multi)
    local t
    if sel then
      t = self.selection_caret
    else
      t = self.entry_prefix
    end
    if multi and type(self.multi_icon) == "string" then
      t = utils.truncate(t, fn.strdisplaywidth(t) - fn.strdisplaywidth(self.multi_icon), "") .. self.multi_icon
    end
    return t
  end

  local line = api.nvim_buf_get_lines(self.results_bufnr, row, row + 1, false)[1]
  if not line then
    log.trace(string.format("no line found at row %d in buffer %d", row, self.results_bufnr))
    return
  end

  local old_caret = string.sub(line, 0, #prefix(true)) == prefix(true) and prefix(true)
    or string.sub(line, 0, #prefix(true, true)) == prefix(true, true) and prefix(true, true)
    or string.sub(line, 0, #prefix(false)) == prefix(false) and prefix(false)
    or string.sub(line, 0, #prefix(false, true)) == prefix(false, true) and prefix(false, true)
  if old_caret == false then
    log.warn(string.format("can't identify old caret in line: %s", line))
    return
  end

  local pre = prefix(entry == self._selection_entry, self:is_multi_selected(entry))
  -- Only change the first couple characters, nvim_buf_set_text leaves the existing highlights
  api.nvim_buf_set_text(self.results_bufnr, row, 0, row, #old_caret, { pre })
  return pre
end

--- Refresh the previewer based on the current `status` of the picker
function Picker:refresh_previewer()
  local status = state.get_status(self.prompt_bufnr)
  if
    self.previewer
    and status.layout.preview
    and status.layout.preview.winid
    and api.nvim_win_is_valid(status.layout.preview.winid)
  then
    self.previewer:preview(self._selection_entry, status)
    if self.preview_border then
      if self.fix_preview_title then
        return
      end

      local new_title = self.previewer:title(self._selection_entry, config.values.dynamic_preview_title)
      if new_title ~= nil and new_title ~= self.preview_title then
        self.preview_title = new_title
        self.layout.preview.border:change_title(new_title)
      end
    end
  end
end

function Picker:cycle_previewers(next)
  local size = #self.all_previewers
  if size == 1 then
    return
  end

  self.current_previewer_index = self.current_previewer_index + next
  if self.current_previewer_index > size then
    self.current_previewer_index = 1
  elseif self.current_previewer_index < 1 then
    self.current_previewer_index = size
  end

  if self.previewer then
    self.previewer = self.all_previewers[self.current_previewer_index]
    self:refresh_previewer()
  elseif self.hidden_previewer then
    self.hidden_previewer = self.all_previewers[self.current_previewer_index]
  end
end

--- Called by the entry manager when the results from `index` on changed (an insertion shifts all
--- results after it). They are drawn by `_draw_results`: right away if the last draw is at least
--- `DRAW_INTERVAL` ago, else after that delay. So results still fill in while a finder streams them,
--- but each row is drawn once per batch instead of on every insertion; the completor draws the rest.
---@param index number
function Picker:_results_changed(index)
  if not self._dirty_from or index < self._dirty_from then
    self._dirty_from = index
  end
  if not self._last_draw or vim.uv.hrtime() - self._last_draw >= DRAW_INTERVAL * 1e6 then
    self:_draw_results()
  elseif not self._draw_scheduled then
    self._draw_scheduled = true
    vim.defer_fn(function()
      self._draw_scheduled = false
      self:_draw_results()
    end, DRAW_INTERVAL)
  end
end

--- Draw the shown results that changed since the last draw (see `_results_changed`), replacing
--- their rows in one go.
function Picker:_draw_results()
  local from = self._dirty_from
  self._dirty_from = nil
  self._last_draw = vim.uv.hrtime()
  if not from or self.closed or self:is_done() or not api.nvim_buf_is_valid(self.results_bufnr) then
    return
  end
  local last = math.min(self.manager:num_results(), self.max_results)
  if from > last then
    return
  end

  local bufnr, prefix = self.results_bufnr, self.entry_prefix
  local entries, displays, display_hls = {}, {}, {}
  for index = from, last do
    local entry = self.manager:get_entry(index)
    local display, display_highlights = entry_display.resolve(self, entry)
    if not display then
      log.info("Weird entry", entry)
      display = ""
    end
    display = prefix .. display
    -- this only fails when people leave newlines in their results, so clean it up for them
    if display:find("\n", 1, true) then
      display = display:gsub("\n", " | ")
    end
    local k = index - from + 1
    entries[k], displays[k], display_hls[k] = entry, display, display_highlights or false
  end

  -- rows of the first and last changed result, and the lines in buffer order
  local first_row, last_row, lines
  if self.sorting_strategy == "ascending" then
    first_row, last_row, lines = from - 1, last - 1, displays
  else
    first_row, last_row, lines = self.max_results - last, self.max_results - from, {}
    for k = #displays, 1, -1 do
      lines[#lines + 1] = displays[k]
    end
  end
  local ok, msg = pcall(api.nvim_buf_set_lines, bufnr, first_row, last_row + 1, false, lines)
  if not ok then
    log.debug("Failed to set lines...", msg)
    return
  end

  -- replaced lines keep their extmarks: clear the old highlights
  api.nvim_buf_clear_namespace(bufnr, ns_telescope_matching, first_row, last_row + 1)
  self.highlighter:clear_display(first_row, last_row + 1)
  local prompt = self:_get_prompt()
  for k, entry in ipairs(entries) do
    local row = self:get_row(from + k - 1)
    if display_hls[k] then
      self.highlighter:hi_display(row, prefix, display_hls[k])
    end
    if entry == self._selection_entry or self:is_multi_selected(entry) then
      self:update_prefix(entry, row)
    end
    self:highlight_one_row(bufnr, prompt, displays[k], row)
  end
end

--- Reset tracked information for this picker
function Picker:_reset_track()
  self.stats.processed = 0
  self.stats.filtered = 0
end

--- Increment the count of the tracked info at `self.stats[key]`
---@param key string
function Picker:_increment(key)
  self.stats[key] = (self.stats[key] or 0) + 1
end

function Picker:register_completion_callback(cb)
  table.insert(self._completion_callbacks, cb)
end

function Picker:clear_completion_callbacks()
  self._completion_callbacks = {}
end

function Picker:_on_complete()
  for _, v in ipairs(self._completion_callbacks) do
    pcall(v, self)
  end
end

--- Close all open Telescope pickers
function Picker:close_existing_pickers()
  for _, prompt_bufnr in ipairs(state.get_existing_prompt_bufnrs()) do
    pcall(actions.close, prompt_bufnr)
  end
end

--- Returns a function that sets virtual text for the count indicator
--- e.g. "10/50" as "filtered"/"processed"
---@param prompt_win number
---@param prompt_bufnr number
---@return function
function Picker:get_status_updater(prompt_win, prompt_bufnr)
  return function(opts)
    if self.closed or not api.nvim_buf_is_valid(prompt_bufnr) then
      return
    end

    local current_prompt = self:_get_prompt()
    if not current_prompt then
      return
    end

    if not api.nvim_win_is_valid(prompt_win) then
      return
    end

    local text = self:get_status_text(opts)
    api.nvim_buf_clear_namespace(prompt_bufnr, ns_telescope_prompt, 0, -1)
    api.nvim_buf_set_extmark(prompt_bufnr, ns_telescope_prompt, 0, 0, {
      virt_text = { { text, "TelescopePromptCounter" } },
      virt_text_pos = "right_align",
    })
  end
end

--- Returns a function that will process an element.
--- Returned function handles updating the "filtered" and "processed" counts
--- as appropriate and runs the sorters score function. It returns true once the find is stale.
---@param prompt string
---@param status_updater function
---@return function
function Picker:get_result_processor(prompt, status_updater)
  local running = { completed = false } -- no table per result
  local ignore_patterns = self.file_ignore_patterns or {}
  local ignored -- entry -> whether a pattern matches it
  if ignore_patterns[1] then
    -- entries of static and oneshot finders come again with every prompt: check each only once
    self._ignored = self._ignored or setmetatable({}, { __mode = "k" })
    ignored = self._ignored
  end
  local matches = self._matches or { n = 0 }
  local list = matches.list

  local cb_add = function(score, entry)
    -- may need the prompt for tiebreak
    self.manager:add_entry(self, score, entry, prompt)
    if list then
      local n = matches.n + 1
      matches.n, list[n] = n, entry
    end
    status_updater(running)
  end

  local cb_filter = function(_)
    self:_increment "filtered"
  end

  return function(entry)
    if matches.stale then
      return true
    end

    if not entry or entry.valid == false then
      return
    end

    if ignored then
      local skip = ignored[entry]
      if skip == nil then
        skip = false
        -- the file name, or false if there is none
        local file = vim.nonnil(entry.filename, type(entry.value) == "string" and entry.value)
        if file then
          for _, v in ipairs(ignore_patterns) do
            if string.find(file, v) then
              skip = true
              break
            end
          end
        end
        ignored[entry] = skip
      end
      if skip then
        return
      end
    end

    self:_increment "processed"

    self.sorter:score(prompt, entry, cb_add, cb_filter)
  end
end

--- Narrowing: when the prompt extends the previous one, only the previous matches can match, so
--- score just those (in finder order, so results are identical) instead of the finder's results.
--- Only for a `prompt_independent` finder and a discarding sorter (`prefilter` opts out of
--- discarding).
function Picker:_narrowable()
  local sorter = self.sorter
  return self.finder.prompt_independent and sorter.discard and rawget(sorter, "_was_discarded") == nil
end

--- The previous matches, if the sorter kept its discards (the prompt extends the previous one, and
--- its `start` didn't reset them) and the previous prompt was processed completely.
---@param discarded table: `sorter._discard_state.filtered` before `sorter:_start(prompt)`
---@return table|nil: the previous matches
function Picker:_narrowed_candidates(discarded)
  local prev = self._matches
  if
    prev
    and prev.complete
    and prev.list
    and prev.finder == self.finder
    and discarded ~= nil
    and self.sorter._discard_state.filtered == discarded
  then
    return prev
  end
end

--- Process the narrowed `candidates` like a static finder would process its results.
function Picker:_process_candidates(candidates, process_result, process_complete)
  -- count the skipped entries as processed and filtered, as the finder would have
  local skipped = candidates.processed - candidates.n
  self.stats.processed, self.stats.filtered = skipped, skipped
  _async.process_list(candidates.list, candidates.n, process_result)
  process_complete()
end

--- Handles updating the picker after all the entries are scored/processed.
---@param results_bufnr number
---@param prompt string
---@param status_updater function
function Picker:get_result_completor(results_bufnr, prompt, status_updater)
  return vim.schedule_wrap(function()
    if self.closed == true or self:is_done() then
      return
    end

    self:_draw_results()
    self:_do_selection(prompt)

    status_updater { completed = true }

    self:clear_extra_rows(results_bufnr)
    self.sorter:_finish(prompt)

    if self.sorting_strategy == "descending" then
      local visible_result_rows = api.nvim_win_get_height(self.results_win)
      api.nvim_win_set_cursor(self.results_win, { self.max_results - visible_result_rows, 1 })
      api.nvim_win_set_cursor(self.results_win, { self.max_results, 1 })
    else
      api.nvim_win_set_cursor(self.results_win, { 1, 0 })
    end
    self:_on_complete()
  end)
end

function Picker:_do_selection(prompt)
  local selection_strategy = self.selection_strategy or "reset"
  if selection_strategy == "row" then
    if self._selection_row == nil and self.default_selection_index ~= nil then
      self:set_selection(self:get_row(self.default_selection_index))
    else
      self:set_selection(self:get_selection_row())
    end
  elseif selection_strategy == "follow" then
    if self._selection_row == nil and self.default_selection_index ~= nil then
      self:set_selection(self:get_row(self.default_selection_index))
    else
      local index = self.manager:find_entry(self:get_selection())

      if index then
        local follow_row = self:get_row(index)
        self:set_selection(follow_row)
      else
        self:set_selection(self:get_reset_row())
      end
    end
  elseif selection_strategy == "reset" then
    if self.default_selection_index ~= nil then
      self:set_selection(self:get_row(self.default_selection_index))
    else
      self:set_selection(self:get_reset_row())
    end
  elseif selection_strategy == "closest" then
    if prompt == "" and self.default_selection_index ~= nil then
      self:set_selection(self:get_row(self.default_selection_index))
    else
      self:set_selection(self:get_reset_row())
    end
  elseif selection_strategy == "none" then
    if self._selection_entry then
      local old_entry, old_row = self._selection_entry, self._selection_row
      self:reset_selection() -- required to reset selection before updating prefix
      if old_row >= 0 then
        self:update_prefix(old_entry, old_row)
        self.highlighter:hi_multiselect(old_row, self:is_multi_selected(old_entry))
      end
    end
    return
  else
    error("Unknown selection strategy: " .. selection_strategy)
  end
end

--- Wrapper function for `Picker:new` that incorporates user provided `opts`
--- with the telescope `defaults`. If both define `attach_mappings` or `on_close`, both are called
--- (the defaults first).
---@param opts table
---@param defaults table
---@return Picker
pickers.new = function(opts, defaults)
  opts = opts or {}
  defaults = defaults or {}
  local result = {}

  for k, v in pairs(opts) do
    assert(type(k) == "string" or type(k) == "number", "Should be string or number, found: " .. type(k))
    result[k] = v
  end

  for k, v in pairs(defaults) do
    if result[k] == nil then
      assert(type(k) == "string", "Should be string, defaults")
      result[k] = v
    else
      -- For attach mappings, we want people to be able to pass in another function
      -- and apply their mappings after we've applied our defaults.
      if k == "attach_mappings" then
        local opt_value = result[k]
        result[k] = function(...)
          v(...)
          return opt_value(...)
        end
      elseif k == "on_close" then
        local opt_value = result[k]
        result[k] = function()
          v()
          opt_value()
        end
      end
    end
  end

  if result["previewer"] == false then
    result["previewer"] = defaults["previewer"]
    result["__hide_previewer"] = true
  elseif result["previewer"] == true then
    result["previewer"] = defaults["previewer"]
  elseif type(opts["preview"]) == "table" and opts["preview"]["hide_on_startup"] then
    result["__hide_previewer"] = true
  end

  return Picker:new(result)
end

--- Close the picker which has prompt with buffer number `prompt_bufnr`
---@param prompt_bufnr number
function pickers.on_close_prompt(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker
  require("telescope.actions.state").get_current_history():reset()

  if type(picker.cache_picker) == "table" then
    local cached_pickers = state.get_global_key "cached_pickers" or {}

    if type(picker.cache_picker.index) == "number" then
      if not vim.tbl_isempty(cached_pickers) then
        table.remove(cached_pickers, picker.cache_picker.index)
      end
    end

    -- if picker was disabled post-hoc (e.g. `cache_picker = false` conclude after deletion)
    if picker.cache_picker.disabled ~= true then
      if picker.cache_picker.limit_entries > 0 then
        -- edge case: starting in normal mode and not having run a search means having no manager instantiated
        if picker.manager then
          picker.manager:truncate(picker.cache_picker.limit_entries)
        else
          picker.manager = EntryManager:new(picker.max_results, picker._results_changed)
        end
      end
      local curr_prompt = picker:_get_prompt()
      picker.default_text = curr_prompt
      picker.cache_picker.selection_row = picker._selection_row

      -- Only cache if prompt is not empty or ignore_empty_prompt is false
      if not picker.cache_picker.ignore_empty_prompt or (curr_prompt and curr_prompt ~= "") then
        picker.cache_picker.cached_prompt = curr_prompt
        table.insert(cached_pickers, 1, picker)
        picker.cache_picker.is_cached = true
      end

      -- release pickers
      if picker.cache_picker.num_pickers > 0 then
        while #cached_pickers > picker.cache_picker.num_pickers do
          table.remove(cached_pickers, #cached_pickers)
        end
      end
      state.set_global_key("cached_pickers", cached_pickers)
    end
  end

  if picker.sorter then
    picker.sorter:_destroy()
  end

  if picker.all_previewers then
    for _, v in ipairs(picker.all_previewers) do
      v:teardown()
    end
  end

  if picker.finder then
    picker.finder:close()
  end

  -- so we dont call close_windows multiple times we clear that autocmd
  api.nvim_clear_autocmds {
    group = "PickerInsert",
    event = "BufLeave",
    buf = prompt_bufnr,
  }
  picker.close_windows(status)

  vim.o.mousemoveevent = picker.__original_mousemoveevent

  if picker.on_close then
    picker.on_close()
  end
end

function pickers.on_resize_window(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker

  picker:full_layout_update()
end

--- Get the prompt text without the prompt prefix.
function Picker:_get_prompt()
  local cursor_line = api.nvim_win_get_cursor(self.prompt_win)[1] - 1
  return api.nvim_buf_get_lines(self.prompt_bufnr, cursor_line, cursor_line + 1, false)[1]:sub(#self.prompt_prefix + 1)
end

function Picker:_reset_highlights()
  self.highlighter:clear_display()
  api.nvim_buf_clear_namespace(self.results_bufnr, ns_telescope_matching, 0, -1)
end

-- Toggles whether finder is attached to prompt buffer input
function Picker:_toggle_finder_attach()
  self._finder_attached = not self._finder_attached
end

function Picker:_detach()
  if self._main_task then
    self._main_task:close()
  end
  self.finder:close()

  self.closed = true
end

function Picker:_get_next_filtered_prompt()
  local prompt = self:_get_prompt()
  local on_input_result = self._on_input_filter_cb(prompt) or {}

  local new_prompt = on_input_result.prompt
  if new_prompt then
    prompt = new_prompt
  end

  local new_finder = on_input_result.updated_finder
  if new_finder then
    self.finder:close()
    self.finder = new_finder
  end

  return prompt
end

function Picker:_resume_picker()
  -- resume previous picker: draw its results
  self._dirty_from = 1
  self:_draw_results()
  self.cache_picker.is_cached = false
  local on_resume_complete = function()
    if api.nvim_buf_is_valid(self.prompt_bufnr) then
      api.nvim_buf_call(self.prompt_bufnr, function()
        vim.cmd "do User TelescopeResumePost"
      end)
    end
  end
  -- if text changed, required to set anew to restart finder; otherwise hl and selection
  if self.cache_picker.cached_prompt ~= self.default_text then
    self:set_prompt(self.default_text)
    on_resume_complete()
  else
    -- scheduling required to apply highlighting and selection appropriately
    vim.schedule(function()
      if self.cache_picker.selection_row ~= nil then
        self:set_selection(self.cache_picker.selection_row)
      end
      on_resume_complete()
    end)
  end
end

pickers._Picker = Picker

return pickers
