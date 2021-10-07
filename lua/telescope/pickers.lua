require "telescope"

local a = vim.api

local async = require "plenary.async"
local await_schedule = async.util.scheduler
local channel = require("plenary.async.control").channel
local popup = require "plenary.popup"

local actions = require "telescope.actions"
local action_set = require "telescope.actions.set"
local config = require "telescope.config"
local debounce = require "telescope.debounce"
local deprecated = require "telescope.deprecated"
local log = require "telescope.log"
local mappings = require "telescope.mappings"
local state = require "telescope.state"
local utils = require "telescope.utils"

local entry_display = require "telescope.pickers.entry_display"
local p_highlighter = require "telescope.pickers.highlights"
local p_scroller = require "telescope.pickers.scroller"
local p_window = require "telescope.pickers.window"

local EntryManager = require "telescope.entry_manager"
local MultiSelect = require "telescope.pickers.multi"

local get_default = utils.get_default

local ns_telescope_matching = a.nvim_create_namespace "telescope_matching"
local ns_telescope_prompt = a.nvim_create_namespace "telescope_prompt"
local ns_telescope_prompt_prefix = a.nvim_create_namespace "telescope_prompt_prefix"

local pickers = {}

-- TODO: Add overscroll option for results buffer

--- Picker is the main UI that shows up to interact w/ your results.
-- Takes a filter & a previewr
local Picker = {}
Picker.__index = Picker

--- Create new picker
function Picker:new(opts)
  opts = opts or {}

  if opts.layout_strategy and opts.get_window_options then
    error "layout_strategy and get_window_options are not compatible keys"
  end

  -- Reset actions for any replaced / enhanced actions.
  -- TODO: Think about how we could remember to NOT have to do this...
  --        I almost forgot once already, cause I'm not smart enough to always do it.
  actions._clear()
  action_set._clear()

  deprecated.picker_window_options(opts)

  local layout_strategy = get_default(opts.layout_strategy, config.values.layout_strategy)

  local obj = setmetatable({
    prompt_title = get_default(opts.prompt_title, "Prompt"),
    results_title = get_default(opts.results_title, "Results"),
    preview_title = get_default(opts.preview_title, "Preview"),

    prompt_prefix = get_default(opts.prompt_prefix, config.values.prompt_prefix),
    selection_caret = get_default(opts.selection_caret, config.values.selection_caret),
    entry_prefix = get_default(opts.entry_prefix, config.values.entry_prefix),
    initial_mode = get_default(opts.initial_mode, config.values.initial_mode),
    debounce = get_default(tonumber(opts.debounce), nil),

    default_text = opts.default_text,
    get_status_text = get_default(opts.get_status_text, config.values.get_status_text),
    _on_input_filter_cb = opts.on_input_filter_cb or function() end,

    finder = assert(opts.finder, "Finder is required."),
    sorter = opts.sorter or require("telescope.sorters").empty(),

    all_previewers = opts.previewer,
    current_previewer_index = 1,

    default_selection_index = opts.default_selection_index,

    cwd = opts.cwd,

    _find_id = 0,
    _completion_callbacks = type(opts._completion_callbacks) == "table" and opts._completion_callbacks or {},
    manager = (type(opts.manager) == "table" and getmetatable(opts.manager) == EntryManager) and opts.manager,
    _multi = (type(opts._multi) == "table" and getmetatable(opts._multi) == getmetatable(MultiSelect:new()))
        and opts._multi
      or MultiSelect:new(),

    track = get_default(opts.track, false),
    stats = {},

    attach_mappings = opts.attach_mappings,
    file_ignore_patterns = get_default(opts.file_ignore_patterns, config.values.file_ignore_patterns),

    scroll_strategy = get_default(opts.scroll_strategy, config.values.scroll_strategy),
    sorting_strategy = get_default(opts.sorting_strategy, config.values.sorting_strategy),
    selection_strategy = get_default(opts.selection_strategy, config.values.selection_strategy),

    layout_strategy = layout_strategy,
    layout_config = config.smarter_depth_2_extend(opts.layout_config or {}, config.values.layout_config or {}),

    window = {
      winblend = get_default(
        opts.winblend,
        type(opts.window) == "table" and opts.window.winblend or config.values.winblend
      ),
      border = get_default(opts.border, type(opts.window) == "table" and opts.window.border or config.values.border),
      borderchars = get_default(
        opts.borderchars,
        type(opts.window) == "table" and opts.window.borderchars or config.values.borderchars
      ),
    },

    cache_picker = config.resolve_table_opts(opts.cache_picker, vim.deepcopy(config.values.cache_picker)),
  }, self)

  obj.get_window_options = opts.get_window_options or p_window.get_window_options

  if obj.all_previewers ~= nil and obj.all_previewers ~= false then
    if obj.all_previewers[1] == nil then
      obj.all_previewers = { obj.all_previewers }
    end
    obj.previewer = obj.all_previewers[1]
  else
    obj.previewer = false
  end

  -- TODO: It's annoying that this is create and everything else is "new"
  obj.scroller = p_scroller.create(obj.scroll_strategy, obj.sorting_strategy)

  obj.highlighter = p_highlighter.new(obj)

  if opts.on_complete then
    for _, on_complete_item in ipairs(opts.on_complete) do
      obj:register_completion_callback(on_complete_item)
    end
  end

  return obj
end

--- Take a row and get an index.
---@note: Rows are 0-indexed, and `index` is 1 indexed (table index)
---@param index number: The row being displayed
---@return number The row for the picker to display in
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
---@return number The index in line_manager
function Picker:get_index(row)
  if self.sorting_strategy == "ascending" then
    return row + 1
  else
    return self.max_results - row
  end
end

function Picker:get_reset_row()
  if self.sorting_strategy == "ascending" then
    return 0
  else
    return self.max_results - 1
  end
end

function Picker:is_done()
  if not self.manager then
    return true
  end
end

function Picker:clear_extra_rows(results_bufnr)
  if self:is_done() then
    log.trace "Not clearing due to being already complete"
    return
  end

  if not vim.api.nvim_buf_is_valid(results_bufnr) then
    log.debug("Invalid results_bufnr for clearing:", results_bufnr)
    return
  end

  local worst_line, ok, msg
  if self.sorting_strategy == "ascending" then
    local num_results = self.manager:num_results()
    worst_line = self.max_results - num_results

    if worst_line <= 0 then
      return
    end

    ok, msg = pcall(vim.api.nvim_buf_set_lines, results_bufnr, num_results, -1, false, {})
  else
    worst_line = self:get_row(self.manager:num_results())
    if worst_line <= 0 then
      return
    end

    local empty_lines = utils.repeated_table(worst_line, "")
    ok, msg = pcall(vim.api.nvim_buf_set_lines, results_bufnr, 0, worst_line, false, empty_lines)
  end

  if not ok then
    log.debug(msg)
  end

  log.trace("Clearing:", worst_line)
end

function Picker:highlight_displayed_rows(results_bufnr, prompt)
  if not self.sorter or not self.sorter.highlighter then
    return
  end

  vim.api.nvim_buf_clear_namespace(results_bufnr, ns_telescope_matching, 0, -1)

  local displayed_rows = vim.api.nvim_buf_get_lines(results_bufnr, 0, -1, false)
  for row_index = 1, math.min(#displayed_rows, self.max_results) do
    local display = displayed_rows[row_index]

    self:highlight_one_row(results_bufnr, prompt, display, row_index - 1)
  end
end

function Picker:highlight_one_row(results_bufnr, prompt, display, row)
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

      self:_increment "highlights"

      vim.api.nvim_buf_add_highlight(results_bufnr, ns_telescope_matching, highlight, row, start - 1, finish)
    end
  end

  local entry = self.manager:get_entry(self:get_index(row))
  self.highlighter:hi_multiselect(row, self:is_multi_selected(entry))
end

function Picker:can_select_row(row)
  if self.sorting_strategy == "ascending" then
    return row <= self.manager:num_results()
  else
    return row >= 0 and row <= self.max_results and row >= self.max_results - self.manager:num_results()
  end
end

function Picker:_next_find_id()
  local find_id = self._find_id + 1
  self._find_id = find_id

  return find_id
end

function Picker:find()
  self:close_existing_pickers()
  self:reset_selection()

  self.original_win_id = a.nvim_get_current_win()

  -- User autocmd run it before create Telescope window
  vim.cmd [[doautocmd User TelescopeFindPre]]

  -- Create three windows:
  -- 1. Prompt window
  -- 2. Options window
  -- 3. Preview window
  local line_count = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus ~= 0 then
    line_count = line_count - 1
  end

  local popup_opts = self:get_window_options(vim.o.columns, line_count)

  -- `popup.nvim` massaging so people don't have to remember minheight shenanigans
  popup_opts.results.minheight = popup_opts.results.height
  popup_opts.prompt.minheight = popup_opts.prompt.height
  if popup_opts.preview then
    popup_opts.preview.minheight = popup_opts.preview.height
  end

  local results_win, results_opts = popup.create("", popup_opts.results)
  local results_bufnr = a.nvim_win_get_buf(results_win)

  self.results_bufnr = results_bufnr
  self.results_win = results_win

  -- TODO: Should probably always show all the line for results win, so should implement a resize for the windows
  a.nvim_win_set_option(results_win, "wrap", false)
  a.nvim_win_set_option(results_win, "winhl", "Normal:TelescopeNormal")
  a.nvim_win_set_option(results_win, "winblend", self.window.winblend)
  local results_border_win = results_opts.border and results_opts.border.win_id
  if results_border_win then
    vim.api.nvim_win_set_option(results_border_win, "winhl", "Normal:TelescopeResultsBorder")
  end

  local preview_win, preview_opts, preview_bufnr
  if popup_opts.preview then
    preview_win, preview_opts = popup.create("", popup_opts.preview)
    preview_bufnr = a.nvim_win_get_buf(preview_win)

    a.nvim_win_set_option(preview_win, "winhl", "Normal:TelescopePreviewNormal")
    a.nvim_win_set_option(preview_win, "winblend", self.window.winblend)
    local preview_border_win = preview_opts and preview_opts.border and preview_opts.border.win_id
    if preview_border_win then
      vim.api.nvim_win_set_option(preview_border_win, "winhl", "Normal:TelescopePreviewBorder")
    end
  end

  -- TODO: We need to center this and make it prettier...
  local prompt_win, prompt_opts = popup.create("", popup_opts.prompt)
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)
  a.nvim_win_set_option(prompt_win, "winhl", "Normal:TelescopeNormal")
  a.nvim_win_set_option(prompt_win, "winblend", self.window.winblend)
  local prompt_border_win = prompt_opts.border and prompt_opts.border.win_id
  if prompt_border_win then
    vim.api.nvim_win_set_option(prompt_border_win, "winhl", "Normal:TelescopePromptBorder")
  end
  self.prompt_bufnr = prompt_bufnr

  -- Prompt prefix
  local prompt_prefix = self.prompt_prefix
  if prompt_prefix ~= "" then
    a.nvim_buf_set_option(prompt_bufnr, "buftype", "prompt")
    vim.fn.prompt_setprompt(prompt_bufnr, prompt_prefix)
  end
  self.prompt_prefix = prompt_prefix
  self:_reset_prefix_color()

  -- First thing we want to do is set all the lines to blank.
  self.max_results = popup_opts.results.height

  -- TODO(scrolling): This may be a hack when we get a little further into implementing scrolling.
  vim.api.nvim_buf_set_lines(results_bufnr, 0, self.max_results, false, utils.repeated_table(self.max_results, ""))

  -- TODO(status): I would love to get the status text not moving back and forth. Perhaps it is just a problem with
  -- virtual text & prompt buffers or something though. I can't figure out why it would redraw the way it does.
  --
  -- A "hacked" version of this would be to calculate where the area I want the status to go and put a new window there.
  -- With this method, I do not need to worry about padding or antying, just make it take up X characters or something.
  local status_updater = self:get_status_updater(prompt_win, prompt_bufnr)
  local debounced_status = debounce.throttle_leading(status_updater, 50)

  local tx, rx = channel.mpsc()
  self.__on_lines = tx.send

  local find_id = self:_next_find_id()

  local main_loop = async.void(function()
    self.sorter:_init()

    -- Do filetype last, so that users can register at the last second.
    pcall(a.nvim_buf_set_option, prompt_bufnr, "filetype", "TelescopePrompt")
    pcall(a.nvim_buf_set_option, results_bufnr, "filetype", "TelescopeResults")

    -- TODO(async): I wonder if this should actually happen _before_ we nvim_buf_attach.
    -- This way the buffer would always start with what we think it should when we start the loop.
    if self.initial_mode == "insert" or self.initial_mode == "normal" then
      -- required for set_prompt to work adequately
      vim.cmd [[startinsert!]]
      if self.default_text then
        self:set_prompt(self.default_text)
      end
      if self.initial_mode == "normal" then
        -- otherwise (i) insert mode exitted faster than `picker:set_prompt`; (ii) cursor on wrong pos
        await_schedule(function()
          vim.cmd [[stopinsert]]
        end)
      end
    else
      error("Invalid setting for initial_mode: " .. self.initial_mode)
    end

    await_schedule()

    while true do
      -- Wait for the next input
      rx.last()
      await_schedule()

      self:_reset_track()

      if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
        log.debug("ON_LINES: Invalid prompt_bufnr", prompt_bufnr)
        return
      end

      local start_time = vim.loop.hrtime()

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

      -- TODO: Entry manager should have a "bulk" setter. This can prevent a lot of redraws from display
      if self.cache_picker == false or not (self.cache_picker.is_cached == true) then
        self.sorter:_start(prompt)
        self.manager = EntryManager:new(self.max_results, self.entry_adder, self.stats)

        local process_result = self:get_result_processor(find_id, prompt, debounced_status)
        local process_complete = self:get_result_completor(self.results_bufnr, find_id, prompt, status_updater)

        local ok, msg = pcall(function()
          self.finder(prompt, process_result, process_complete)
        end)

        if not ok then
          log.warn("Finder failed with msg: ", msg)
        end

        local diff_time = (vim.loop.hrtime() - start_time) / 1e6
        if self.debounce and diff_time < self.debounce then
          async.util.sleep(self.debounce - diff_time)
        end
      else
        -- resume previous picker
        local index = 1
        for entry in self.manager:iter() do
          self:entry_adder(index, entry, _, true)
          index = index + 1
        end
        self.cache_picker.is_cached = false
        -- if text changed, required to set anew to restart finder; otherwise hl and selection
        if self.cache_picker.cached_prompt ~= self.default_text then
          self:reset_prompt()
          self:set_prompt(self.default_text)
        else
          -- scheduling required to apply highlighting and selection appropriately
          await_schedule(function()
            self:highlight_displayed_rows(self.results_bufnr, self.cache_picker.cached_prompt)
            if self.cache_picker.selection_row ~= nil then
              self:set_selection(self.cache_picker.selection_row)
            end
          end)
        end
      end
    end
  end)

  -- Register attach
  vim.api.nvim_buf_attach(prompt_bufnr, false, {
    on_lines = function(...)
      find_id = self:_next_find_id()

      self._result_completed = false
      status_updater { completed = false }
      tx.send(...)
    end,
    on_detach = function()
      self:_detach()
    end,
  })

  -- TODO: Use WinLeave as well?
  local on_buf_leave = string.format(
    [[  autocmd BufLeave <buffer> ++nested ++once :silent lua require('telescope.pickers').on_close_prompt(%s)]],
    prompt_bufnr
  )

  vim.cmd [[augroup PickerInsert]]
  vim.cmd [[  au!]]
  vim.cmd(on_buf_leave)
  vim.cmd [[augroup END]]

  local preview_border = preview_opts and preview_opts.border
  self.preview_border = preview_border
  local preview_border_win = (preview_border and preview_border.win_id) and preview_border.win_id

  state.set_status(
    prompt_bufnr,
    setmetatable({
      prompt_bufnr = prompt_bufnr,
      prompt_win = prompt_win,
      prompt_border_win = prompt_border_win,

      results_bufnr = results_bufnr,
      results_win = results_win,
      results_border_win = results_border_win,

      preview_bufnr = preview_bufnr,
      preview_win = preview_win,
      preview_border_win = preview_border_win,
      picker = self,
    }, {
      __mode = "kv",
    })
  )

  mappings.apply_keymap(prompt_bufnr, self.attach_mappings, config.values.mappings)

  tx.send()
  main_loop()
end

function Picker:hide_preview()
  -- 1. Hide the window (and border)
  -- 2. Resize prompt & results windows accordingly
end

-- TODO: update multi-select with the correct tag name when available
--- A simple interface to remove an entry from the results window without
--- closing telescope. This either deletes the current selection or all the
--- selections made using multi-select. It can be used to define actions
--- such as deleting buffers or files.
---
--- Example usage:
--- <code>
--- actions.delete_something = function(prompt_bufnr)
---    local current_picker = action_state.get_current_picker(prompt_bufnr)
---    current_picker:delete_selection(function(selection)
---      -- delete the selection outside of telescope
---    end)
--- end
--- </code>
---
--- Example usage in telescope:
---   - `actions.delete_buffer()`
---@param delete_cb function: called with each deleted selection
function Picker:delete_selection(delete_cb)
  vim.validate { delete_cb = { delete_cb, "f" } }
  local original_selection_strategy = self.selection_strategy
  self.selection_strategy = "row"

  local delete_selections = self._multi:get()
  local used_multi_select = true
  if vim.tbl_isempty(delete_selections) then
    table.insert(delete_selections, self:get_selection())
    used_multi_select = false
  end

  local selection_index = {}
  for result_index, result_entry in ipairs(self.finder.results) do
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
    local selection = table.remove(self.finder.results, index)
    delete_cb(selection)
  end

  if used_multi_select then
    self._multi = MultiSelect:new()
  end

  self:refresh()
  vim.schedule(function()
    self.selection_strategy = original_selection_strategy
  end)
end

function Picker:set_prompt(str)
  -- TODO(conni2461): As soon as prompt_buffers are fix use this:
  -- vim.api.nvim_buf_set_lines(self.prompt_bufnr, 0, 1, false, { str })
  vim.api.nvim_feedkeys(str, "n", false)
end

function Picker.close_windows(status)
  local prompt_win = status.prompt_win
  local results_win = status.results_win
  local preview_win = status.preview_win

  local prompt_border_win = status.prompt_border_win
  local results_border_win = status.results_border_win
  local preview_border_win = status.preview_border_win

  local function del_win(name, win_id, force, bdelete)
    if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
      return
    end

    local bufnr = vim.api.nvim_win_get_buf(win_id)
    if bdelete and vim.api.nvim_buf_is_valid(bufnr) and not vim.api.nvim_buf_get_option(bufnr, "buflisted") then
      vim.cmd(string.format("silent! bdelete! %s", bufnr))
    end

    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end

    if not pcall(vim.api.nvim_win_close, win_id, force) then
      log.trace("Unable to close window: ", name, "/", win_id)
    end
  end

  del_win("prompt_win", prompt_win, true)
  del_win("results_win", results_win, true, true)
  del_win("preview_win", preview_win, true, true)

  del_win("prompt_border_win", prompt_border_win, true, true)
  del_win("results_border_win", results_border_win, true, true)
  del_win("preview_border_win", preview_border_win, true, true)

  -- vim.cmd(string.format("bdelete! %s", status.prompt_bufnr))

  -- Major hack?? Why do I have to od this.
  --    Probably because we're currently IN the buffer.
  --    Should wait to do this until after we're done.
  vim.defer_fn(function()
    del_win("prompt_win", prompt_win, true)
  end, 10)

  state.clear_status(status.prompt_bufnr)
end

function Picker:get_selection()
  return self._selection_entry
end

function Picker:get_selection_row()
  return self._selection_row or self.max_results
end

function Picker:move_selection(change)
  self:set_selection(self:get_selection_row() + change)
end

function Picker:add_selection(row)
  local entry = self.manager:get_entry(self:get_index(row))
  self._multi:add(entry)

  self.highlighter:hi_multiselect(row, true)
end

function Picker:remove_selection(row)
  local entry = self.manager:get_entry(self:get_index(row))
  self._multi:drop(entry)

  self.highlighter:hi_multiselect(row, false)
end

function Picker:is_multi_selected(entry)
  return self._multi:is_selected(entry)
end

function Picker:get_multi_selection()
  return self._multi:get()
end

function Picker:toggle_selection(row)
  local entry = self.manager:get_entry(self:get_index(row))
  self._multi:toggle(entry)

  self.highlighter:hi_multiselect(row, self._multi:is_selected(entry))
end

function Picker:reset_selection()
  self._selection_entry = nil
  self._selection_row = nil
end

function Picker:_reset_prefix_color(hl_group)
  self._current_prefix_hl_group = hl_group or nil

  if self.prompt_prefix ~= "" then
    vim.api.nvim_buf_add_highlight(
      self.prompt_bufnr,
      ns_telescope_prompt_prefix,
      self._current_prefix_hl_group or "TelescopePromptPrefix",
      0,
      0,
      #self.prompt_prefix
    )
  end
end

-- TODO(conni2461): Maybe _ prefix these next two functions
-- TODO(conni2461): Next two functions only work together otherwise color doesn't work
--                  Probably a issue with prompt buffers
function Picker:change_prompt_prefix(new_prefix, hl_group)
  if not new_prefix then
    return
  end

  if new_prefix ~= "" then
    vim.fn.prompt_setprompt(self.prompt_bufnr, new_prefix)
  else
    vim.api.nvim_buf_set_text(self.prompt_bufnr, 0, 0, 0, #self.prompt_prefix, {})
    vim.api.nvim_buf_set_option(self.prompt_bufnr, "buftype", "")
  end
  self.prompt_prefix = new_prefix
  self:_reset_prefix_color(hl_group)
end

function Picker:reset_prompt(text)
  local prompt_text = self.prompt_prefix .. (text or "")
  vim.api.nvim_buf_set_lines(self.prompt_bufnr, 0, -1, false, { prompt_text })

  self:_reset_prefix_color(self._current_prefix_hl_group)

  if text then
    vim.api.nvim_win_set_cursor(self.prompt_win, { 1, #prompt_text })
  end
end

--- opts.new_prefix:   Either as string or { new_string, hl_group }
--- opts.reset_prompt: bool
function Picker:refresh(finder, opts)
  opts = opts or {}
  if opts.new_prefix then
    local handle = type(opts.new_prefix) == "table" and unpack or function(x)
      return x
    end
    self:change_prompt_prefix(handle(opts.new_prefix))
  end
  if opts.reset_prompt then
    self:reset_prompt()
  end

  if finder then
    self.finder:close()
    self.finder = finder
    self._multi = MultiSelect:new()
  end

  self.__on_lines(nil, nil, nil, 0, 1)
end

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
  if not a.nvim_buf_is_valid(results_bufnr) then
    return
  end

  if row > a.nvim_buf_line_count(results_bufnr) then
    log.debug(
      string.format("Should not be possible to get row this large %s %s", row, a.nvim_buf_line_count(results_bufnr))
    )

    return
  end

  local entry = self.manager:get_entry(self:get_index(row))
  state.set_global_key("selected_entry", entry)

  if not entry then
    return
  end

  -- TODO: Probably should figure out what the rows are that made this happen...
  --        Probably something with setting a row that's too high for this?
  --        Not sure.
  local set_ok, set_errmsg = pcall(function()
    local prompt = self:_get_prompt()

    -- Handle adding '> ' to beginning of selections
    if self._selection_row then
      -- Only change the first couple characters, nvim_buf_set_text leaves the existing highlights
      a.nvim_buf_set_text(
        results_bufnr,
        self._selection_row,
        0,
        self._selection_row,
        #self.selection_caret,
        { self.entry_prefix }
      )
      self.highlighter:hi_multiselect(self._selection_row, self:is_multi_selected(self._selection_entry))

      -- local display = a.nvim_buf_get_lines(results_bufnr, old_row, old_row + 1, false)[1]
      -- display = '  ' .. display
      -- a.nvim_buf_set_lines(results_bufnr, old_row, old_row + 1, false, {display})

      -- self.highlighter:hi_display(old_row, '  ', display_highlights)
      -- self.highlighter:hi_sorter(old_row, prompt, display)
    end

    local caret = self.selection_caret

    local display, display_highlights = entry_display.resolve(self, entry)
    display = caret .. display

    -- TODO: You should go back and redraw the highlights for this line from the sorter.
    -- That's the only smart thing to do.
    if not a.nvim_buf_is_valid(results_bufnr) then
      log.debug "Invalid buf somehow..."
      return
    end
    a.nvim_buf_set_lines(results_bufnr, row, row + 1, false, { display })

    -- don't highlight the ' ' at the end of caret
    self.highlighter:hi_selection(row, caret:sub(1, -2))
    self.highlighter:hi_display(row, caret, display_highlights)
    self.highlighter:hi_sorter(row, prompt, display)

    self.highlighter:hi_multiselect(row, self:is_multi_selected(entry))
  end)

  if not set_ok then
    log.debug(set_errmsg)
    return
  end

  if self._selection_entry == entry and self._selection_row == row then
    return
  end

  -- TODO: Get row & text in the same obj
  self._selection_entry = entry
  self._selection_row = row

  self:refresh_previewer()
end

function Picker:refresh_previewer()
  local status = state.get_status(self.prompt_bufnr)
  if status.preview_win and self.previewer then
    self:_increment "previewed"

    self.previewer:preview(self._selection_entry, status)
    if self.preview_border then
      if config.values.dynamic_preview_title == true then
        self.preview_border:change_title(self.previewer:dynamic_title(self._selection_entry))
      else
        self.preview_border:change_title(self.previewer:title())
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

  self.previewer = self.all_previewers[self.current_previewer_index]
  self:refresh_previewer()
end

function Picker:entry_adder(index, entry, _, insert)
  if not entry then
    return
  end

  local row = self:get_row(index)

  -- If it's less than 0, then we don't need to show it at all.
  if row < 0 then
    log.debug("ON_ENTRY: Weird row", row)
    return
  end

  local display, display_highlights = entry_display.resolve(self, entry)
  if not display then
    log.info("Weird entry", entry)
    return
  end

  -- This is the two spaces to manage the '> ' stuff.
  -- Maybe someday we can use extmarks or floaty text or something to draw this and not insert here.
  -- until then, insert two spaces
  local prefix = self.entry_prefix
  display = prefix .. display

  self:_increment "displayed"

  -- TODO: Don't need to schedule this if we schedule the adder.
  local offset = insert and 0 or 1
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(self.results_bufnr) then
      log.debug "ON_ENTRY: Invalid buffer"
      return
    end

    -- TODO: Does this every get called?
    -- local line_count = vim.api.nvim_win_get_height(self.results_win)
    local line_count = vim.api.nvim_buf_line_count(self.results_bufnr)
    if row > line_count then
      return
    end

    if insert then
      if self.sorting_strategy == "descending" then
        vim.api.nvim_buf_set_lines(self.results_bufnr, 0, 1, false, {})
      end
    end

    local set_ok, msg = pcall(vim.api.nvim_buf_set_lines, self.results_bufnr, row, row + offset, false, { display })
    if set_ok and display_highlights then
      self.highlighter:hi_display(row, prefix, display_highlights)
    end

    if not set_ok then
      log.debug("Failed to set lines...", msg)
    end

    -- This pretty much only fails when people leave newlines in their results.
    --  So we'll clean it up for them if it fails.
    if not set_ok and display:find "\n" then
      display = display:gsub("\n", " | ")
      vim.api.nvim_buf_set_lines(self.results_bufnr, row, row + 1, false, { display })
    end
  end)
end

function Picker:_reset_track()
  self.stats.processed = 0
  self.stats.displayed = 0
  self.stats.display_fn = 0
  self.stats.previewed = 0
  self.stats.status = 0

  self.stats.filtered = 0
  self.stats.highlights = 0
end

function Picker:_increment(key)
  self.stats[key] = (self.stats[key] or 0) + 1
end

function Picker:_decrement(key)
  self.stats[key] = (self.stats[key] or 0) - 1
end

-- TODO: Decide how much we want to use this.
--  Would allow for better debugging of items.
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

function Picker:close_existing_pickers()
  for _, prompt_bufnr in ipairs(state.get_existing_prompts()) do
    pcall(actions.close, prompt_bufnr)
  end
end

function Picker:get_status_updater(prompt_win, prompt_bufnr)
  return function(opts)
    if self.closed or not vim.api.nvim_buf_is_valid(prompt_bufnr) then
      return
    end

    local current_prompt = self:_get_prompt()
    if not current_prompt then
      return
    end

    if not vim.api.nvim_win_is_valid(prompt_win) then
      return
    end

    local text = self:get_status_text(opts)
    vim.api.nvim_buf_clear_namespace(prompt_bufnr, ns_telescope_prompt, 0, -1)
    vim.api.nvim_buf_set_extmark(prompt_bufnr, ns_telescope_prompt, 0, 0, {
      virt_text = { { text, "NonText" } },
      virt_text_pos = "right_align",
    })

    self:_increment "status"
  end
end

function Picker:get_result_processor(find_id, prompt, status_updater)
  local cb_add = function(score, entry)
    self.manager:add_entry(self, score, entry)
    status_updater { completed = false }
  end

  local cb_filter = function(_)
    self:_increment "filtered"
  end

  return function(entry)
    if find_id ~= self._find_id then
      return true
    end

    self:_increment "processed"

    if not entry or entry.valid == false then
      return
    end

    -- TODO: Probably should asyncify this / cache this / do something because this probably takes
    -- a ton of time on large results.
    log.trace("Processing result... ", entry)
    for _, v in ipairs(self.file_ignore_patterns or {}) do
      local file = vim.F.if_nil(entry.filename, type(entry.value) == "string" and entry.value) -- false if none is true
      if file then
        if string.find(file, v) then
          log.trace("SKIPPING", entry.value, "because", v)
          self:_decrement "processed"
          return
        end
      end
    end

    self.sorter:score(prompt, entry, cb_add, cb_filter)
  end
end

function Picker:get_result_completor(results_bufnr, find_id, prompt, status_updater)
  return vim.schedule_wrap(function()
    if self.closed == true or self:is_done() then
      return
    end

    self:_do_selection(prompt)

    state.set_global_key("current_line", self:_get_prompt())
    status_updater { completed = true }

    self:clear_extra_rows(results_bufnr)
    self:highlight_displayed_rows(results_bufnr, prompt)
    self.sorter:_finish(prompt)

    self:_on_complete()

    self._result_completed = true
  end)
end

function Picker:_do_selection(prompt)
  local selection_strategy = self.selection_strategy or "reset"
  -- TODO: Either: always leave one result or make sure we actually clean up the results when nothing matches
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
  else
    error("Unknown selection strategy: " .. selection_strategy)
  end
end

pickers.new = function(opts, defaults)
  local result = {}

  for k, v in pairs(opts or {}) do
    assert(type(k) == "string", "Should be string, opts")
    result[k] = v
  end

  for k, v in pairs(defaults or {}) do
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
      end
    end
  end

  return Picker:new(result)
end

function pickers.on_close_prompt(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker

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
          picker.manager.linked_states:truncate(picker.cache_picker.limit_entries)
        else
          picker.manager = EntryManager:new(picker.max_results, picker.entry_adder, picker.stats)
        end
      end
      picker.default_text = picker:_get_prompt()
      picker.cache_picker.selection_row = picker._selection_row
      picker.cache_picker.cached_prompt = picker:_get_prompt()
      picker.cache_picker.is_cached = true
      table.insert(cached_pickers, 1, picker)

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

  if picker.previewer then
    picker.previewer:teardown()
  end

  if picker.finder then
    picker.finder:close()
  end

  picker.close_windows(status)
end

--- Get the prompt text without the prompt prefix.
function Picker:_get_prompt()
  return vim.api.nvim_buf_get_lines(self.prompt_bufnr, 0, 1, false)[1]:sub(#self.prompt_prefix + 1)
end

function Picker:_reset_highlights()
  self.highlighter:clear_display()
end

function Picker:_detach()
  self.finder:close()

  -- TODO: Can we add a "cleanup" / "teardown" function that completely removes these.
  -- self.finder = nil
  -- self.previewer = nil
  -- self.sorter = nil
  -- self.manager = nil

  self.closed = true
end

pickers._Picker = Picker

return pickers
