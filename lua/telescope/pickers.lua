local a = vim.api
local popup = require('popup')

local async_lib = require('plenary.async_lib')
local async_util = async_lib.util

local async = async_lib.async
local await = async_lib.await
local channel = async_util.channel

require('telescope')

local actions = require('telescope.actions')
local action_set = require('telescope.actions.set')
local config = require('telescope.config')
local debounce = require('telescope.debounce')
local log = require('telescope.log')
local mappings = require('telescope.mappings')
local state = require('telescope.state')
local utils = require('telescope.utils')

local entry_display = require('telescope.pickers.entry_display')
local p_highlighter = require('telescope.pickers.highlights')
local p_scroller = require('telescope.pickers.scroller')
local p_window = require('telescope.pickers.window')

local EntryManager = require('telescope.entry_manager')
local MultiSelect = require('telescope.pickers.multi')

local get_default = utils.get_default

local ns_telescope_matching = a.nvim_create_namespace('telescope_matching')
local ns_telescope_prompt = a.nvim_create_namespace('telescope_prompt')
local ns_telescope_prompt_prefix = a.nvim_create_namespace('telescope_prompt_prefix')

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
    error("layout_strategy and get_window_options are not compatible keys")
  end

  -- Reset actions for any replaced / enhanced actions.
  -- TODO: Think about how we could remember to NOT have to do this...
  --        I almost forgot once already, cause I'm not smart enough to always do it.
  actions._clear()
  action_set._clear()

  local layout_strategy = get_default(opts.layout_strategy, config.values.layout_strategy)

  local obj = setmetatable({
    prompt_title = get_default(opts.prompt_title, "Prompt"),
    results_title = get_default(opts.results_title, "Results"),
    preview_title = get_default(opts.preview_title, "Preview"),

    prompt_prefix = get_default(opts.prompt_prefix, config.values.prompt_prefix),
    selection_caret = get_default(opts.selection_caret, config.values.selection_caret),
    entry_prefix = get_default(opts.entry_prefix, config.values.entry_prefix),
    initial_mode = get_default(opts.initial_mode, config.values.initial_mode),

    default_text = opts.default_text,
    get_status_text = get_default(opts.get_status_text, config.values.get_status_text),
    _on_input_filter_cb = opts.on_input_filter_cb or function() end,

    finder = opts.finder,
    sorter = opts.sorter or require('telescope.sorters').empty(),

    all_previewers = opts.previewer,
    current_previewer_index = 1,

    default_selection_index = opts.default_selection_index,

    cwd = opts.cwd,

    _find_id = 0,
    _completion_callbacks = {},
    _multi = MultiSelect:new(),

    track = get_default(opts.track, false),
    stats = {},

    attach_mappings = opts.attach_mappings,
    file_ignore_patterns = get_default(opts.file_ignore_patterns, config.values.file_ignore_patterns),

    sorting_strategy = get_default(opts.sorting_strategy, config.values.sorting_strategy),
    selection_strategy = get_default(opts.selection_strategy, config.values.selection_strategy),

    layout_strategy = layout_strategy,
    layout_config = get_default(
      opts.layout_config,
      (config.values.layout_defaults or {})[layout_strategy]
    ) or {},

    window = {
      -- TODO: This won't account for different layouts...
      -- TODO: If it's between 0 and 1, it's a percetnage.
      -- TODO: If its's a single number, it's always that many columsn
      -- TODO: If it's a list, of length 2, then it's a range of min to max?
      height = get_default(opts.height, 0.8),
      width = get_default(opts.width, config.values.width),

      get_preview_width = get_default(opts.preview_width, config.values.get_preview_width),

      results_width = get_default(opts.results_width, config.values.results_width),
      results_height = get_default(opts.results_height, config.values.results_height),

      winblend = get_default(opts.winblend, config.values.winblend),
      prompt_position = get_default(opts.prompt_position, config.values.prompt_position),

      -- Border config
      border = get_default(opts.border, config.values.border),
      borderchars = get_default(opts.borderchars, config.values.borderchars),
    },

    preview_cutoff = get_default(opts.preview_cutoff, config.values.preview_cutoff),
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
  obj.scroller = p_scroller.create(
    get_default(opts.scroll_strategy, config.values.scroll_strategy),
    obj.sorting_strategy
  )

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
  if self.sorting_strategy == 'ascending' then
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
  if self.sorting_strategy == 'ascending' then
    return row + 1
  else
    return self.max_results - row
  end
end

function Picker:get_reset_row()
  if self.sorting_strategy == 'ascending' then
    return 0
  else
    return self.max_results - 1
  end
end

function Picker:is_done()
  if not self.manager then return true end
end

function Picker:clear_extra_rows(results_bufnr)
  if self:is_done() then
    log.trace("Not clearing due to being already complete")
    return
  end

  if not vim.api.nvim_buf_is_valid(results_bufnr) then
    log.debug("Invalid results_bufnr for clearing:", results_bufnr)
    return
  end

  local worst_line, ok, msg
  if self.sorting_strategy == 'ascending' then
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
  local highlights = self:_track("_highlight_time", self.sorter.highlighter, self.sorter, prompt, display)

  if highlights then
    for _, hl in ipairs(highlights) do
      local highlight, start, finish
      if type(hl) == 'table' then
        highlight = hl.highlight or 'TelescopeMatching'
        start = hl.start
        finish = hl.finish or hl.start
      elseif type(hl) == 'number' then
        highlight = 'TelescopeMatching'
        start = hl
        finish = hl
      else
        error('Invalid higlighter fn')
      end

      self:_increment('highlights')

      vim.api.nvim_buf_add_highlight(
        results_bufnr,
        ns_telescope_matching,
        highlight,
        row,
        start - 1,
        finish
      )
    end
  end

  local entry = self.manager:get_entry(self:get_index(row))
  self.highlighter:hi_multiselect(row, self:is_multi_selected(entry))
end

function Picker:can_select_row(row)
  if self.sorting_strategy == 'ascending' then
    return row <= self.manager:num_results()
  else
    return row <= self.max_results and row >= self.max_results - self.manager:num_results()
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

  assert(self.finder, "Finder is required to do picking")

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

  local results_win, results_opts = popup.create('', popup_opts.results)
  local results_bufnr = a.nvim_win_get_buf(results_win)

  self.results_bufnr = results_bufnr
  self.results_win = results_win

  -- TODO: Should probably always show all the line for results win, so should implement a resize for the windows
  a.nvim_win_set_option(results_win, 'wrap', false)
  a.nvim_win_set_option(results_win, 'winhl', 'Normal:TelescopeNormal')
  a.nvim_win_set_option(results_win, 'winblend', self.window.winblend)
  local results_border_win = results_opts.border and results_opts.border.win_id
  if results_border_win then
    vim.api.nvim_win_set_option(results_border_win, 'winhl', 'Normal:TelescopeResultsBorder')
  end


  local preview_win, preview_opts, preview_bufnr
  if popup_opts.preview then
    preview_win, preview_opts = popup.create('', popup_opts.preview)
    preview_bufnr = a.nvim_win_get_buf(preview_win)

    a.nvim_win_set_option(preview_win, 'winhl', 'Normal:TelescopePreviewNormal')
    a.nvim_win_set_option(preview_win, 'winblend', self.window.winblend)
    local preview_border_win = preview_opts and preview_opts.border and preview_opts.border.win_id
    if preview_border_win then
      vim.api.nvim_win_set_option(preview_border_win, 'winhl', 'Normal:TelescopePreviewBorder')
    end
  end

  -- TODO: We need to center this and make it prettier...
  local prompt_win, prompt_opts = popup.create('', popup_opts.prompt)
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)
  a.nvim_win_set_option(prompt_win, 'winhl', 'Normal:TelescopeNormal')
  a.nvim_win_set_option(prompt_win, 'winblend', self.window.winblend)
  local prompt_border_win = prompt_opts.border and prompt_opts.border.win_id
  if prompt_border_win then vim.api.nvim_win_set_option(prompt_border_win, 'winhl', 'Normal:TelescopePromptBorder') end

  -- Prompt prefix
  local prompt_prefix = self.prompt_prefix
  if prompt_prefix ~= '' then
    a.nvim_buf_set_option(prompt_bufnr, 'buftype', 'prompt')
    vim.fn.prompt_setprompt(prompt_bufnr, prompt_prefix)
  end
  self.prompt_prefix = prompt_prefix
  self:_reset_prefix_color()

  -- Temporarily disabled: Draw the screen ASAP. This makes things feel speedier.
  -- vim.cmd [[redraw]]

  -- First thing we want to do is set all the lines to blank.
  self.max_results = popup_opts.results.height

  vim.api.nvim_buf_set_lines(results_bufnr, 0, self.max_results, false, utils.repeated_table(self.max_results, ""))

  local status_updater = self:get_status_updater(prompt_win, prompt_bufnr)
  local debounced_status = debounce.throttle_leading(status_updater, 50)
  -- local debounced_status = status_updater

  local tx, rx = channel.mpsc()
  self.__on_lines = tx.send

  local main_loop = async(function()
    while true do
      await(async_lib.scheduler())

      local _, _, _, first_line, last_line = await(rx.last())
      self:_reset_track()

      if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
        log.debug("ON_LINES: Invalid prompt_bufnr", prompt_bufnr)
        return
      end

      if not first_line then first_line = 0 end
      if not last_line then last_line = 1 end

      if first_line > 0 or last_line > 1 then
        log.debug("ON_LINES: Bad range", first_line, last_line, self:_get_prompt())
        return
      end

      local original_prompt = self:_get_prompt()
      local on_input_result = self._on_input_filter_cb(original_prompt) or {}

      local prompt = on_input_result.prompt or original_prompt
      local finder = on_input_result.updated_finder

      if finder then
        self.finder:close()
        self.finder = finder
      end

      if self.sorter then self.sorter:_start(prompt) end

      -- TODO: Entry manager should have a "bulk" setter. This can prevent a lot of redraws from display
      self.manager = EntryManager:new(self.max_results, self.entry_adder, self.stats)

      local find_id = self:_next_find_id()
      local process_result = self:get_result_processor(find_id, prompt, debounced_status)
      local process_complete = self:get_result_completor(self.results_bufnr, find_id, prompt, status_updater)

      local ok, msg = pcall(function()
        self.finder(prompt, process_result, vim.schedule_wrap(process_complete))
      end)

      if not ok then
        log.warn("Failed with msg: ", msg)
      end
    end
  end)

  -- Register attach
  vim.api.nvim_buf_attach(prompt_bufnr, false, {
    on_lines = tx.send,
    on_detach = function()
      -- TODO: Can we add a "cleanup" / "teardown" function that completely removes these.
      self.finder = nil
      self.previewer = nil
      self.sorter = nil
      self.manager = nil

      self.closed = true

      -- TODO: Should we actually do this?
      collectgarbage(); collectgarbage()
    end,
  })

  if self.sorter then self.sorter:_init() end
  async_lib.run(main_loop())
  status_updater()

  -- TODO: Use WinLeave as well?
  local on_buf_leave = string.format(
    [[  autocmd BufLeave <buffer> ++nested ++once :silent lua require('telescope.pickers').on_close_prompt(%s)]],
    prompt_bufnr)

  vim.cmd([[augroup PickerInsert]])
  vim.cmd([[  au!]])
  vim.cmd(    on_buf_leave)
  vim.cmd([[augroup END]])

  self.prompt_bufnr = prompt_bufnr

  local preview_border = preview_opts and preview_opts.border
  self.preview_border = preview_border
  local preview_border_win = (preview_border and preview_border.win_id) and preview_border.win_id

  state.set_status(prompt_bufnr, setmetatable({
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
  }, { __mode = 'kv' }))

  mappings.apply_keymap(prompt_bufnr, self.attach_mappings, config.values.mappings)

  -- Do filetype last, so that users can register at the last second.
  pcall(a.nvim_buf_set_option, prompt_bufnr, 'filetype', 'TelescopePrompt')

  if self.default_text then
    vim.api.nvim_buf_set_lines(prompt_bufnr, 0, 1, false, {self.default_text})
  end

  if self.initial_mode == "insert" then
    vim.cmd [[startinsert!]]
  elseif self.initial_mode ~= "normal" then
    error("Invalid setting for initial_mode: " .. self.initial_mode)
  end
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
--- <pre>
--- actions.delete_something = function(prompt_bufnr)
---    local current_picker = action_state.get_current_picker(prompt_bufnr)
---    current_picker:delete_selection(function(selection)
---      -- delete the selection outside of telescope
---    end)
--- end
--- </pre>
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
  table.sort(selection_index, function(x, y) return x > y end)
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
    if bdelete
        and vim.api.nvim_buf_is_valid(bufnr)
        and not vim.api.nvim_buf_get_option(bufnr, 'buflisted') then
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

  if self.prompt_prefix ~= '' then
    vim.api.nvim_buf_add_highlight(self.prompt_bufnr,
      ns_telescope_prompt_prefix,
      self._current_prefix_hl_group or 'TelescopePromptPrefix',
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
  if not new_prefix then return end

  if new_prefix ~= '' then
    vim.fn.prompt_setprompt(self.prompt_bufnr, new_prefix)
  else
    vim.api.nvim_buf_set_text(self.prompt_bufnr, 0, 0, 0, #self.prompt_prefix, {})
    vim.api.nvim_buf_set_option(self.prompt_bufnr, 'buftype', '')
  end
  self.prompt_prefix = new_prefix
  self:_reset_prefix_color(hl_group)
end

function Picker:reset_prompt(text)
  local prompt_text = self.prompt_prefix .. (text or '')
  vim.api.nvim_buf_set_lines(self.prompt_bufnr, 0, -1, false, { prompt_text })

  self:_reset_prefix_color(self._current_prefix_hl_group)

  if text then
    vim.api.nvim_win_set_cursor(self.prompt_win, {1, #prompt_text})
  end
end

--- opts.new_prefix:   Either as string or { new_string, hl_group }
--- opts.reset_prompt: bool
function Picker:refresh(finder, opts)
  opts = opts or {}
  if opts.new_prefix then
    local handle = type(opts.new_prefix) == 'table' and unpack or function(x) return x end
    self:change_prompt_prefix(handle(opts.new_prefix))
  end
  if opts.reset_prompt then self:reset_prompt() end

  if finder then
    self.finder:close()
    self.finder = finder
    self._multi = MultiSelect:new()
  end

  self.__on_lines(nil, nil, nil, 0, 1)
end

function Picker:set_selection(row)
  if not self.manager then return end

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
    log.debug(string.format(
      "Should not be possible to get row this large %s %s",
        row,
        a.nvim_buf_line_count(results_bufnr)
    ))

    return
  end

  local entry = self.manager:get_entry(self:get_index(row))
  state.set_global_key("selected_entry", entry)

  if not entry then return end

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
        self._selection_row, 0,
        self._selection_row, #self.selection_caret,
        { self.entry_prefix }
      )
      self.highlighter:hi_multiselect(
        self._selection_row,
        self:is_multi_selected(self._selection_entry)
      )

      -- local display = a.nvim_buf_get_lines(results_bufnr, old_row, old_row + 1, false)[1]
      -- display = '  ' .. display
      -- a.nvim_buf_set_lines(results_bufnr, old_row, old_row + 1, false, {display})

      -- self.highlighter:hi_display(old_row, '  ', display_highlights)
      -- self.highlighter:hi_sorter(old_row, prompt, display)
    end

    local caret = self.selection_caret
    -- local display = string.format('%s %s', caret,
    --   (a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1] or ''):sub(3)
    -- )
    local display, display_highlights = entry_display.resolve(self, entry)
    display = caret .. display

    -- TODO: You should go back and redraw the highlights for this line from the sorter.
    -- That's the only smart thing to do.
    if not a.nvim_buf_is_valid(results_bufnr) then
      log.debug("Invalid buf somehow...")
      return
    end
    a.nvim_buf_set_lines(results_bufnr, row, row + 1, false, {display})

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
    self:_increment("previewed")

    self.previewer:preview(
      self._selection_entry,
      status
    )
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
  if size == 1 then return end

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
  if not entry then return end

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

  self:_increment("displayed")

  -- TODO: Don't need to schedule this if we schedule the adder.
  local offset = insert and 0 or 1
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(self.results_bufnr) then
      log.debug("ON_ENTRY: Invalid buffer")
      return
    end

    -- TODO: Does this every get called?
    -- local line_count = vim.api.nvim_win_get_height(self.results_win)
    local line_count = vim.api.nvim_buf_line_count(self.results_bufnr)
    if row > line_count then
      return
    end

    if insert then
      if self.sorting_strategy == 'descending' then
        vim.api.nvim_buf_set_lines(self.results_bufnr, 0, 1, false, {})
      end
    end

    local set_ok, msg = pcall(vim.api.nvim_buf_set_lines, self.results_bufnr, row, row + offset, false, {display})
    if set_ok and display_highlights then
      self.highlighter:hi_display(row, prefix, display_highlights)
    end

    if not set_ok then
      log.debug("Failed to set lines...", msg)
    end

    -- This pretty much only fails when people leave newlines in their results.
    --  So we'll clean it up for them if it fails.
    if not set_ok and display:find("\n") then
      display = display:gsub("\n", " | ")
      vim.api.nvim_buf_set_lines(self.results_bufnr, row, row + 1, false, {display})
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

function Picker:_track(key, func, ...)
  local start, final
  if self.track then
    start = vim.loop.hrtime()
  end

  -- Hack... we just do this so that we can track stuff that returns two values.
  local res1, res2 = func(...)

  if self.track then
    final = vim.loop.hrtime()
    self.stats[key] = final - start + self.stats[key]
  end

  return res1, res2
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
  return function()
    local text = self:get_status_text()
    if self.closed or not vim.api.nvim_buf_is_valid(prompt_bufnr) then return end
    local current_prompt = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1]
    if not current_prompt then
      return
    end

    if not vim.api.nvim_win_is_valid(prompt_win) then
      return
    end

    local prompt_len = #current_prompt

    local padding = string.rep(" ", vim.api.nvim_win_get_width(prompt_win) - prompt_len - #text - 3)
    vim.api.nvim_buf_clear_namespace(prompt_bufnr, ns_telescope_prompt, 0, 1)
    vim.api.nvim_buf_set_virtual_text(
      prompt_bufnr,
      ns_telescope_prompt,
      0,
      { {padding .. text, "NonText"} },
      {}
    )

    -- TODO: Wait for bfredl
    -- vim.api.nvim_buf_set_extmark(prompt_bufnr, ns_telescope_prompt, 0, 0, {
    --   end_line      = 0,
    --   -- end_col       = start_column + #text,
    --   virt_text     = { { text, "NonText", } },
    --   virt_text_pos = "eol",
    -- })

    self:_increment("status")
  end
end


function Picker:get_result_processor(find_id, prompt, status_updater)
  local cb_add = function(score, entry)
    self.manager:add_entry(self, score, entry)
    status_updater()
  end

  local cb_filter = function(_)
    self:_increment("filtered")
  end

  return function(entry)
    if find_id ~= self._find_id
        or self.closed
        or self:is_done() then
      return true
    end

    self:_increment("processed")

    if not entry or entry.valid == false then
      return
    end

    -- TODO: Probably should asyncify this / cache this / do something because this probably takes
    -- a ton of time on large results.
    log.trace("Processing result... ", entry)
    for _, v in ipairs(self.file_ignore_patterns or {}) do
      local file = type(entry.value) == 'string' and entry.value or entry.filename
      if file then
        if string.find(file, v) then
          log.trace("SKIPPING", entry.value, "because", v)
          self:_decrement("processed")
          return
        end
      end
    end

    self.sorter:score(prompt, entry, cb_add, cb_filter)
  end
end

function Picker:get_result_completor(results_bufnr, find_id, prompt, status_updater)
  return function()
    if self.closed == true or self:is_done() then return end

    local selection_strategy = self.selection_strategy or 'reset'

    -- TODO: Either: always leave one result or make sure we actually clean up the results when nothing matches
    if selection_strategy == 'row' then
      if self._selection_row == nil and self.default_selection_index ~= nil then
        self:set_selection(self:get_row(self.default_selection_index))
      else
        self:set_selection(self:get_selection_row())
      end
    elseif selection_strategy == 'follow' then
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
    elseif selection_strategy == 'reset' then
      if self.default_selection_index ~= nil then
        self:set_selection(self:get_row(self.default_selection_index))
      else
        self:set_selection(self:get_reset_row())
      end
    else
      error('Unknown selection strategy: ' .. selection_strategy)
    end

    local current_line = vim.api.nvim_get_current_line():sub(self.prompt_prefix:len() + 1)
    state.set_global_key('current_line', current_line)

    status_updater()

    self:clear_extra_rows(results_bufnr)
    self:highlight_displayed_rows(results_bufnr, prompt)
    if self.sorter then self.sorter:_finish(prompt) end

    self:_on_complete()
  end
end



pickers.new = function(opts, defaults)
  local result = {}

  for k, v in pairs(opts or {}) do
    assert(type(k) == 'string', "Should be string, opts")
    result[k] = v
  end

  for k, v in pairs(defaults or {}) do
    if result[k] == nil then
      assert(type(k) == 'string', "Should be string, defaults")
      result[k] = v
    else
      -- For attach mappings, we want people to be able to pass in another function
      -- and apply their mappings after we've applied our defaults.
      if k == 'attach_mappings' then
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

  if picker.sorter then
    picker.sorter:_destroy()
  end

  if picker.previewer then
    picker.previewer:teardown()
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

pickers._Picker = Picker


return pickers
