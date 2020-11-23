local a = vim.api
local popup = require('popup')

require('telescope')

local actions = require('telescope.actions')
local config = require('telescope.config')
local debounce = require('telescope.debounce')
local resolve = require('telescope.config.resolve')
local log = require('telescope.log')
local mappings = require('telescope.mappings')
local state = require('telescope.state')
local utils = require('telescope.utils')

local layout_strategies = require('telescope.pickers.layout_strategies')
local entry_display = require('telescope.pickers.entry_display')

local EntryManager = require('telescope.entry_manager')

local get_default = utils.get_default

-- TODO: Make this work with deep extend I think.
local extend = function(opts, defaults)
  local result = {}

  for k, v in pairs(opts or {}) do
    assert(type(k) == 'string', "Should be string, opts")
    result[k] = v
  end

  for k, v in pairs(defaults or {}) do
    if result[k] == nil then
      assert(type(k) == 'string', "Should be string, defaults")
      result[k] = v
    end
  end

  return result
end

local ns_telescope_selection = a.nvim_create_namespace('telescope_selection')
local ns_telescope_entry = a.nvim_create_namespace('telescope_entry')
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
  actions._clear()

  local layout_strategy = get_default(opts.layout_strategy, config.values.layout_strategy)

  return setmetatable({
    prompt_title = get_default(opts.prompt_title, "Prompt"),
    results_title = get_default(opts.results_title, "Results"),
    preview_title = get_default(opts.preview_title, "Preview"),

    prompt_prefix = get_default(opts.prompt_prefix, config.values.prompt_prefix),

    default_text = opts.default_text,
    get_status_text = get_default(opts.get_status_text, config.values.get_status_text),

    finder = opts.finder,
    sorter = opts.sorter,
    previewer = opts.previewer,
    default_selection_index = opts.default_selection_index,

    _completion_callbacks = {},

    track = get_default(opts.track, false),
    stats = {},

    attach_mappings = opts.attach_mappings,
    file_ignore_patterns = get_default(opts.file_ignore_patterns, config.values.file_ignore_patterns),

    sorting_strategy = get_default(opts.sorting_strategy, config.values.sorting_strategy),
    selection_strategy = get_default(opts.selection_strategy, config.values.selection_strategy),
    scroll_strategy = get_default(opts.scroll_strategy, config.values.scroll_strategy),

    get_window_options = opts.get_window_options,
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
end

function Picker:_get_initial_window_options()
  local popup_border = resolve.win_option(self.window.border)
  local popup_borderchars = resolve.win_option(self.window.borderchars)

  local preview = {
    title = self.preview_title,
    border = popup_border.preview,
    borderchars = popup_borderchars.preview,
    enter = false,
    highlight = false
  }

  local results = {
    title = self.results_title,
    border = popup_border.results,
    borderchars = popup_borderchars.results,
    enter = false,
  }

  local prompt = {
    title = self.prompt_title,
    border = popup_border.prompt,
    borderchars = popup_borderchars.prompt,
    enter = true
  }

  return {
    preview = preview,
    results = results,
    prompt = prompt,
  }
end

function Picker:get_window_options(max_columns, max_lines)
  local layout_strategy = self.layout_strategy
  local getter = layout_strategies[layout_strategy]

  if not getter then
    error("Not a valid layout strategy: " .. layout_strategy)
  end

  return getter(self, max_columns, max_lines)
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
  if self:is_done() then return end

  if not vim.api.nvim_buf_is_valid(results_bufnr) then
    log.debug("Invalid results_bufnr for clearing:", results_bufnr)
    return
  end

  local worst_line
  if self.sorting_strategy == 'ascending' then
    local num_results = self.manager:num_results()
    worst_line = self.max_results - num_results

    if worst_line <= 0 then
      return
    end

    pcall(vim.api.nvim_buf_set_lines, results_bufnr, num_results, self.max_results, false, {})
  else
    worst_line = self:get_row(self.manager:num_results())
    if worst_line <= 0 then
      return
    end

    local empty_lines = utils.repeated_table(worst_line, "")
    pcall(vim.api.nvim_buf_set_lines, results_bufnr, 0, worst_line, false, empty_lines)
  end

  log.trace("Clearing:", worst_line)
end

function Picker:highlight_displayed_rows(results_bufnr, prompt)
  if not self.sorter or not self.sorter.highlighter then
    return
  end

  vim.api.nvim_buf_clear_namespace(results_bufnr, ns_telescope_matching, 0, -1)

  local displayed_rows = vim.api.nvim_buf_get_lines(results_bufnr, 0, -1, false)
  for row_index = 1, #displayed_rows do
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
end

function Picker:can_select_row(row)
  if self.sorting_strategy == 'ascending' then
    return row <= self.manager:num_results()
  else
    return row <= self.max_results and row >= self.max_results - self.manager:num_results()
  end
end

function Picker:find()
  self:close_existing_pickers()
  self:reset_selection()

  assert(self.finder, "Finder is required to do picking")

  self.original_win_id = a.nvim_get_current_win()

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
  if results_border_win then vim.api.nvim_win_set_option(results_border_win, 'winhl', 'Normal:TelescopeResultsBorder') end


  local preview_win, preview_opts, preview_bufnr
  if popup_opts.preview then
    preview_win, preview_opts = popup.create('', popup_opts.preview)
    preview_bufnr = a.nvim_win_get_buf(preview_win)

    a.nvim_win_set_option(preview_win, 'winhl', 'Normal:TelescopeNormal')
    a.nvim_win_set_option(preview_win, 'winblend', self.window.winblend)
    local preview_border_win = preview_opts and preview_opts.border and preview_opts.border.win_id
    if preview_border_win then vim.api.nvim_win_set_option(preview_border_win, 'winhl', 'Normal:TelescopePreviewBorder') end

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

    if not vim.endswith(prompt_prefix, " ") then
      prompt_prefix = prompt_prefix .. " "
    end
    vim.fn.prompt_setprompt(prompt_bufnr, prompt_prefix)

    a.nvim_buf_add_highlight(prompt_bufnr, ns_telescope_prompt_prefix, 'TelescopePromptPrefix', 0, 0, #prompt_prefix)
  end

  -- Temporarily disabled: Draw the screen ASAP. This makes things feel speedier.
  -- vim.cmd [[redraw]]

  -- First thing we want to do is set all the lines to blank.
  self.max_results = popup_opts.results.height

  vim.api.nvim_buf_set_lines(results_bufnr, 0, self.max_results, false, utils.repeated_table(self.max_results, ""))

  local selection_strategy = self.selection_strategy or 'reset'

  local update_status = function()
    local text = self:get_status_text()
    local current_prompt = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, 1, false)[1]
    if not current_prompt then
      return
    end

    if not vim.api.nvim_win_is_valid(prompt_win) then
      return
    end

    local padding = string.rep(" ", vim.api.nvim_win_get_width(prompt_win) - #current_prompt - #text - 3)
    vim.api.nvim_buf_clear_namespace(prompt_bufnr, ns_telescope_prompt, 0, 1)
    vim.api.nvim_buf_set_virtual_text(prompt_bufnr, ns_telescope_prompt, 0, { {padding .. text, "NonText"} }, {})

    self:_increment("status")
  end

  local debounced_status = debounce.throttle_leading(update_status, 50)

  local on_lines = function(_, _, _, first_line, last_line)
    self:_reset_track()

    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
      log.debug("ON_LINES: Invalid prompt_bufnr", prompt_bufnr)
      return
    end

    if first_line > 0 or last_line > 1 then
      log.debug("ON_LINES: Bad range", first_line, last_line)
      return
    end

    local prompt = vim.trim(vim.api.nvim_buf_get_lines(prompt_bufnr, first_line, last_line, false)[1]:sub(#prompt_prefix))

    if self.sorter then
      self.sorter:_start(prompt)
    end

    -- TODO: Statusbar possibilities here.
    -- vim.api.nvim_buf_set_virtual_text(prompt_bufnr, 0, 1, { {"hello", "Error"} }, {})

    -- TODO: Entry manager should have a "bulk" setter. This can prevent a lot of redraws from display

    self.manager = EntryManager:new(self.max_results, self.entry_adder)
    -- self.manager = EntryManager:new(self.max_results, self.entry_adder, self.stats)

    local process_result = function(entry)
      if self:is_done() then return end

      self:_increment("processed")

      if not entry then
        log.debug("No entry...")
        return
      end

      -- TODO: Should we even have valid?
      if entry.valid == false then
        return
      end

      log.trace("Processing result... ", entry)

      for _, v in ipairs(self.file_ignore_patterns or {}) do
        if string.find(entry.value, v) then
          log.debug("SKPIPING", entry.value, "because", v)
          return
        end
      end

      local sort_ok, sort_score = nil, 0
      if self.sorter then
        sort_ok, sort_score = self:_track("_sort_time", pcall, self.sorter.score, self.sorter, prompt, entry)

        if not sort_ok then
          log.warn("Sorting failed with:", prompt, entry, sort_score)
          return
        end

        if sort_score == -1 then
          self:_increment("filtered")
          log.trace("Filtering out result: ", entry)
          return
        end
      end

      self:_track("_add_time", self.manager.add_entry, self.manager, self, sort_score, entry)

      debounced_status()
    end

    local process_complete = function()
      if self:is_done() then return end

      -- TODO: We should either: always leave one result or make sure we actually clean up the results when nothing matches
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

      self:clear_extra_rows(results_bufnr)
      self:highlight_displayed_rows(results_bufnr, prompt)

      -- TODO: Cleanup.
      self.stats._done = vim.loop.hrtime()
      self.stats.time = (self.stats._done - self.stats._start) / 1e9

      local function do_times(key)
        self.stats[key] = self.stats["_" .. key] / 1e9
      end

      do_times("sort_time")
      do_times("add_time")
      do_times("highlight_time")

      self:_on_complete()

      update_status()
    end

    local ok, msg = pcall(function()
      self.finder(prompt, process_result, vim.schedule_wrap(process_complete))
    end)

    if not ok then
      log.warn("Failed with msg: ", msg)
    end
  end

  on_lines(nil, nil, nil, 0, 1)
  update_status()

  -- Register attach
  vim.api.nvim_buf_attach(prompt_bufnr, false, {
    on_lines = on_lines,
    on_detach = vim.schedule_wrap(function()
      on_lines = nil

      -- TODO: Can we add a "cleanup" / "teardown" function that completely removes these.
      self.finder = nil
      self.previewer = nil
      self.sorter = nil
      self.manager = nil

      -- TODO: Should we actually do this?
      collectgarbage(); collectgarbage()
    end),
  })

  -- TODO: Use WinLeave as well?
  local on_buf_leave = string.format(
    [[  autocmd BufLeave <buffer> ++nested ++once :silent lua require('telescope.pickers').on_close_prompt(%s)]],
    prompt_bufnr)

  vim.cmd([[augroup PickerInsert]])
  vim.cmd([[  au!]])
  vim.cmd(    on_buf_leave)
  vim.cmd([[augroup END]])

  self.prompt_bufnr = prompt_bufnr

  local preview_border_win = preview_opts and preview_opts.border and preview_opts.border.win_id

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

  vim.cmd [[startinsert!]]
end

function Picker:hide_preview()
  -- 1. Hide the window (and border)
  -- 2. Resize prompt & results windows accordingly
end


function Picker.close_windows(status)
  local prompt_win = status.prompt_win
  local results_win = status.results_win
  local preview_win = status.preview_win

  local prompt_border_win = status.prompt_border_win
  local results_border_win = status.results_border_win
  local preview_border_win = status.preview_border_win

  local function del_win(name, win_id, force, bdelete)
    if not vim.api.nvim_win_is_valid(win_id) then
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
  self.multi_select[entry] = true
end

function Picker:display_multi_select(results_bufnr)
  for entry, _ in pairs(self.multi_select) do
    local index = self.manager:find_entry(entry)
    if index then
      vim.api.nvim_buf_add_highlight(
        results_bufnr,
        ns_telescope_selection,
        "TelescopeMultiSelection",
        self:get_row(index),
        0,
        -1
      )
    end
  end
end

function Picker:reset_selection()
  self._selection_entry = nil
  self._selection_row = nil

  self.multi_select = {}
end

function Picker:_handle_scroll_strategy(row)
  if self.scroll_strategy == "cycle" then
    if row >= self.max_results then
      row = 0
    elseif row < 0 then
      row = self.max_results - 1
    end
  else
    if row >= self.max_results then
      row = self.max_results - 1
    elseif row < 0 then
      row = 0
    end
  end

  return row
end

function Picker:set_selection(row)
  -- TODO: Loop around behavior?
  -- TODO: Scrolling past max results
  row = self:_handle_scroll_strategy(row)

  if not self:can_select_row(row) then
    -- If the current selected row exceeds number of currently displayed
    -- elements we have to reset it. Affectes sorting_strategy = 'row'.
    if not self:can_select_row(self:get_selection_row()) then
      row = self:get_row(self.manager:num_results())
    else
      log.debug("Cannot select row:", row, self.manager:num_results(), self.max_results)
      return
    end
  end

  -- local entry = self.manager:get_entry(self.max_results - row + 1)
  local entry = self.manager:get_entry(self:get_index(row))
  local status = state.get_status(self.prompt_bufnr)
  local results_bufnr = status.results_bufnr

  state.set_global_key("selected_entry", entry)

  if not vim.api.nvim_buf_is_valid(results_bufnr) then
    return
  end

  -- TODO: Probably should figure out what the rows are that made this happen...
  --        Probably something with setting a row that's too high for this?
  --        Not sure.
  local set_ok, set_errmsg = pcall(function()
    if not a.nvim_buf_is_valid(results_bufnr) then
      return
    end

    local prompt = vim.api.nvim_buf_get_lines(self.prompt_bufnr, 0, 1, false)[1]

    -- Handle adding '> ' to beginning of selections
    if self._selection_row then
      local old_selection = a.nvim_buf_get_lines(results_bufnr, self._selection_row, self._selection_row + 1, false)[1]

      if old_selection then
        local old_display = '  ' .. old_selection:sub(3)
        a.nvim_buf_set_lines(results_bufnr, self._selection_row, self._selection_row + 1, false, {old_display})

        if prompt and self.sorter and self.sorter.highlighter then
          self:highlight_one_row(results_bufnr, prompt, old_display, self._selection_row)
        end
      end
    end

    local caret = '>'
    local display = string.format('%s %s', caret, (a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1] or ''):sub(3))

    -- TODO: You should go back and redraw the highlights for this line from the sorter.
    -- That's the only smart thing to do.
    if not a.nvim_buf_is_valid(results_bufnr) then
      log.debug("Invalid buf somehow...")
      return
    end
    a.nvim_buf_set_lines(results_bufnr, row, row + 1, false, {display})

    a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)
    a.nvim_buf_add_highlight(
      results_bufnr,
      ns_telescope_selection,
      'TelescopeSelectionCaret',
      row,
      0,
      #caret
    )
    a.nvim_buf_add_highlight(
      results_bufnr,
      ns_telescope_selection,
      'TelescopeSelection',
      row,
      #caret,
      -1
    )

    self:display_multi_select(results_bufnr)

    if prompt and self.sorter and self.sorter.highlighter then
      self:highlight_one_row(results_bufnr, prompt, display, row)
    end
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

  if status.preview_win and self.previewer then
    self:_increment("previewed")

    self.previewer:preview(
      entry,
      status
    )
  end
end


function Picker:entry_adder(index, entry, score)
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
  local prefix = TELESCOPE_DEBUG and ('  ' .. score) or '  '
  display = prefix .. display

  self:_increment("displayed")

  -- TODO: Don't need to schedule this if we schedule the adder.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(self.results_bufnr) then
      log.debug("ON_ENTRY: Invalid buffer")
      return
    end

    local set_ok = pcall(vim.api.nvim_buf_set_lines, self.results_bufnr, row, row + 1, false, {display})
    if set_ok and display_highlights then
      -- TODO: This should actually be done during the cursor moving stuff annoyingly.... didn't see this bug yesterday.
      for _, hl_block in ipairs(display_highlights) do
        a.nvim_buf_add_highlight(self.results_bufnr, ns_telescope_entry, hl_block[2], row, #prefix + hl_block[1][1], #prefix + hl_block[1][2])
      end
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

  self.stats._sort_time = 0
  self.stats._add_time = 0
  self.stats._highlight_time = 0
  self.stats._start = vim.loop.hrtime()
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
  self.stats[key] = self.stats[key] + 1
end


-- TODO: Decide how much we want to use this.
--  Would allow for better debugging of items.
function Picker:register_completion_callback(cb)
  table.insert(self._completion_callbacks, cb)
end

function Picker:_on_complete()
  for _, v in ipairs(self._completion_callbacks) do
    v(self)
  end
end

function Picker:close_existing_pickers()
  for _, prompt_bufnr in ipairs(state.get_existing_prompts()) do
    pcall(actions.close, prompt_bufnr)
  end
end


pickers.new = function(opts, defaults)
  return Picker:new(extend(opts, defaults))
end

function pickers.on_close_prompt(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker

  if picker.previewer then
    picker.previewer:teardown()
  end

  -- TODO: This is an attempt to clear all the memory stuff we may have left.
  -- vim.api.nvim_buf_detach(prompt_bufnr)

  picker.close_windows(status)
end

pickers._Picker = Picker


return pickers
