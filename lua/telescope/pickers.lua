local a = vim.api
local popup = require('popup')

local actions = require('telescope.actions')
local config = require('telescope.config')
local resolve = require('telescope.config.resolve')
local layout_strategies = require('telescope.pickers.layout_strategies')
local log = require('telescope.log')
local mappings = require('telescope.mappings')
local state = require('telescope.state')
local utils = require('telescope.utils')

local get_default = utils.get_default

-- TODO: Make this work with deep extend I think.
local extend = function(opts, defaults)
  local result = opts or {}
  for k, v in pairs(defaults or {}) do
    if result[k] == nil then
      result[k] = v
    end
  end

  return result
end

local pickers = {}

-- TODO: Add motions to keybindings
-- TODO: Add relative line numbers?
local default_mappings = {
  i = {
    ["<C-n>"] = actions.move_selection_next,
    ["<C-p>"] = actions.move_selection_previous,

    ["<C-c>"] = actions.close,

    ["<Down>"] = actions.move_selection_next,
    ["<Up>"] = actions.move_selection_previous,

    ["<CR>"] = actions.goto_file_selection_edit,
    ["<C-x>"] = actions.goto_file_selection_split,
    ["<C-v>"] = actions.goto_file_selection_vsplit,
    ["<C-t>"] = actions.goto_file_selection_tabedit,

    ["<C-u>"] = actions.preview_scrolling_up,
    ["<C-d>"] = actions.preview_scrolling_down,
  },

  n = {
    ["<esc>"] = actions.close,
    ["<CR>"] = actions.goto_file_selection_edit,
    ["<C-x>"] = actions.goto_file_selection_split,
    ["<C-v>"] = actions.goto_file_selection_vsplit,
    ["<C-t>"] = actions.goto_file_selection_tabedit,

    -- TODO: This would be weird if we switch the ordering.
    ["j"] = actions.move_selection_next,
    ["k"] = actions.move_selection_previous,

    ["<Down>"] = actions.move_selection_next,
    ["<Up>"] = actions.move_selection_previous,

    ["<C-u>"] = actions.preview_scrolling_up,
    ["<C-d>"] = actions.preview_scrolling_down,
  },
}

-- Picker takes a function (`get_window_options`) that returns the configurations required for three windows:
--  prompt
--  results
--  preview


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

  return setmetatable({
    prompt = opts.prompt,

    results_title = get_default(opts.results_title, "Results"),
    preview_title = get_default(opts.preview_title, "Preview"),

    default_text = opts.default_text,

    finder = opts.finder,
    sorter = opts.sorter,
    previewer = opts.previewer,

    -- opts.mappings => overwrites entire table
    -- opts.override_mappings => merges your table in with defaults.
    --  Add option to change default
    -- opts.attach(bufnr)

    --[[
    function(map)
      map('n', '<esc>', actions.close, [opts])
      telescope.apply_mapping
    end
    --]]
    -- mappings = get_default(opts.mappings, default_mappings),
    attach_mappings = opts.attach_mappings,

    sorting_strategy = get_default(opts.sorting_strategy, config.values.sorting_strategy),
    selection_strategy = get_default(opts.selection_strategy, config.values.selection_strategy),

    layout_strategy = get_default(opts.layout_strategy, config.values.layout_strategy),
    get_window_options = opts.get_window_options,

    window = {
      -- TODO: This won't account for different layouts...
      -- TODO: If it's between 0 and 1, it's a percetnage.
      -- TODO: If its's a single number, it's always that many columsn
      -- TODO: If it's a list, of length 2, then it's a range of min to max?
      height = get_default(opts.height, 0.8),
      width = get_default(opts.width, config.values.width),
      get_preview_width = get_default(opts.preview_width, config.values.get_preview_width),
      results_width = get_default(opts.results_width, 0.8),
      winblend = get_default(opts.winblend, config.values.winblend),

      prompt_position = get_default(opts.prompt_position, config.values.prompt_position),

      -- Border config
      border = get_default(opts.border, config.values.border),
      borderchars = get_default(opts.borderchars, config.values.borderchars),

      -- WIP:
      horizontal_config = get_default(opts.horizontal_config, config.values.horizontal_config),
    },

    preview_cutoff = get_default(opts.preview_cutoff, config.values.preview_cutoff),
  }, Picker)
end

function Picker:_get_initial_window_options(prompt_title)
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
    title = prompt_title,
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

function Picker:get_window_options(max_columns, max_lines, prompt_title)
  local layout_strategy = self.layout_strategy
  local getter = layout_strategies[layout_strategy]

  if not getter then
    error("Not a valid layout strategy: " .. layout_strategy)
  end

  return getter(self, max_columns, max_lines, prompt_title)
end

--- Take a row and get an index
---@param index number: The row being displayed
---@return number The row for the picker to display in
function Picker:get_row(index)
  if self.sorting_strategy == 'ascending' then
    return index
  else
    return self.max_results - index + 1
  end
end

--- Take a row and get an index
---@param row number: The row being displayed
---@return number The index in line_manager
function Picker:get_index(row)
  if self.sorting_strategy == 'ascending' then
    return row
  else
    return self.max_results - row + 1
  end
end

function Picker:get_reset_row()
  if self.sorting_strategy == 'ascending' then
    return 1
  else
    return self.max_results
  end
end

function Picker:clear_extra_rows(results_bufnr)
  if self.sorting_strategy == 'ascending' then
    local num_results = self.manager:num_results()
    local worst_line = self.max_results - num_results

    if worst_line <= 0 then
      return
    end

    vim.api.nvim_buf_set_lines(results_bufnr, num_results + 1, self.max_results, false, {})
  else
    local worst_line = self:get_row(self.manager:num_results())
    if worst_line <= 0 then
      return
    end

    local empty_lines = utils.repeated_table(worst_line, "")
    vim.api.nvim_buf_set_lines(results_bufnr, 0, worst_line, false, empty_lines)

    log.trace("Worst Line after process_complete: %s", worst_line, results_bufnr)
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

  local prompt_string = assert(self.prompt, "Prompt is required.")
  local finder = assert(self.finder, "Finder is required to do picking")
  local sorter = self.sorter

  self.original_win_id = a.nvim_get_current_win()

  -- Create three windows:
  -- 1. Prompt window
  -- 2. Options window
  -- 3. Preview window
  local popup_opts = self:get_window_options(vim.o.columns, vim.o.lines, prompt_string)

  -- `popup.nvim` massaging so people don't have to remember minheight shenanigans
  popup_opts.results.minheight = popup_opts.results.height
  popup_opts.prompt.minheight = popup_opts.prompt.height
  if popup_opts.preview then
    popup_opts.preview.minheight = popup_opts.preview.height
  end

  -- TODO: Add back the borders after fixing some stuff in popup.nvim
  local results_win, results_opts = popup.create('', popup_opts.results)
  local results_bufnr = a.nvim_win_get_buf(results_win)

  -- TODO: Should probably always show all the line for results win, so should implement a resize for the windows
  a.nvim_win_set_option(results_win, 'wrap', false)
  a.nvim_win_set_option(results_win, 'winhl', 'Normal:TelescopeNormal')
  a.nvim_win_set_option(results_win, 'winblend', self.window.winblend)


  local preview_win, preview_opts, preview_bufnr
  if popup_opts.preview then
    preview_win, preview_opts = popup.create('', popup_opts.preview)
    preview_bufnr = a.nvim_win_get_buf(preview_win)

    -- TODO: For some reason, highlighting is kind of weird on these windows.
    --        It may actually be my colorscheme tho...
    a.nvim_win_set_option(preview_win, 'winhl', 'Normal:TelescopeNormal')
    a.nvim_win_set_option(preview_win, 'winblend', self.window.winblend)
  end

  -- TODO: We need to center this and make it prettier...
  local prompt_win, prompt_opts = popup.create('', popup_opts.prompt)
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)
  a.nvim_win_set_option(prompt_win, 'winblend', self.window.winblend)

  a.nvim_win_set_option(prompt_win, 'winhl', 'Normal:TelescopeNormal')

  -- a.nvim_buf_set_option(prompt_bufnr, 'buftype', 'prompt')
  -- vim.fn.prompt_setprompt(prompt_bufnr, prompt_string)

  -- First thing we want to do is set all the lines to blank.
  self.max_results = popup_opts.results.height - 1

  vim.api.nvim_buf_set_lines(results_bufnr, 0, self.max_results, false, utils.repeated_table(self.max_results, ""))

  local selection_strategy = self.selection_strategy or 'reset'

  local on_lines = function(_, _, _, first_line, last_line)
    if not vim.api.nvim_buf_is_valid(prompt_bufnr) then
      return
    end

    local prompt = vim.api.nvim_buf_get_lines(prompt_bufnr, first_line, last_line, false)[1]

    local filtered_amount = 0
    local displayed_amount = 0
    local displayed_fn_amount = 0

    -- TODO: Entry manager should have a "bulk" setter. This can prevent a lot of redraws from display
    self.manager = pickers.entry_manager(
      self.max_results,
      vim.schedule_wrap(function(index, entry)
        if not vim.api.nvim_buf_is_valid(results_bufnr) then
          return
        end

        local row = self:get_row(index)

        -- If it's less than 0, then we don't need to show it at all.
        if row < 0 then
          return
        end
        -- TODO: Do we need to also make sure we don't have something bigger than max results?

        local display
        if type(entry.display) == 'function' then
          displayed_fn_amount = displayed_fn_amount + 1
          display = entry:display()
        elseif type(entry.display) == 'string' then
          display = entry.display
        else
          log.info("Weird entry", entry)
          return
        end

        -- This is the two spaces to manage the '> ' stuff.
        -- Maybe someday we can use extmarks or floaty text or something to draw this and not insert here.
        -- until then, insert two spaces
        display = '  ' .. display

        displayed_amount = displayed_amount + 1

        -- log.info("Setting row", row, "with value", entry)
        local set_ok = pcall(vim.api.nvim_buf_set_lines, results_bufnr, row, row + 1, false, {display})

        -- This pretty much only fails when people leave newlines in their results.
        --  So we'll clean it up for them if it fails.
        if not set_ok and display:find("\n") then
          display = display:gsub("\n", " | ")
          vim.api.nvim_buf_set_lines(results_bufnr, row, row + 1, false, {display})
        end
      end
    ))

    local process_result = function(entry)
      -- TODO: Should we even have valid?
      if entry.valid == false then
        return
      end

      log.trace("Processing result... ", entry)

      local sort_ok, sort_score = nil, 0
      if sorter then
        sort_ok, sort_score = pcall(function ()
          return sorter:score(prompt, entry)
        end)

        if not sort_ok then
          log.warn("Sorting failed with:", prompt, entry, sort_score)
          return
        end

        if sort_score == -1 then
          filtered_amount = filtered_amount + 1
          log.trace("Filtering out result: ", entry)
          return
        end
      end

      self.manager:add_entry(sort_score, entry)
    end

    local process_complete = vim.schedule_wrap(function()
      -- TODO: We should either: always leave one result or make sure we actually clean up the results when nothing matches

      if selection_strategy == 'row' then
        self:set_selection(self:get_selection_row())
      elseif selection_strategy == 'follow' then
        local index = self.manager:find_entry(self:get_selection())

        if index then
          local follow_row = self:get_row(index)
          self:set_selection(follow_row)
        else
          self:set_selection(self:get_reset_row())
        end
      elseif selection_strategy == 'reset' then
        self:set_selection(self:get_reset_row())
      else
        error('Unknown selection strategy: ' .. selection_strategy)
      end

      self:clear_extra_rows(results_bufnr)

      PERF("Filtered Amount    ", filtered_amount)
      PERF("Displayed Amount   ", displayed_amount)
      PERF("Displayed FN Amount", displayed_fn_amount)
    end)

    local ok, msg = pcall(function()
      return finder(prompt, process_result, process_complete)
    end)

    if not ok then
      log.warn("Failed with msg: ", msg)
    end
  end

  -- TODO: Uncomment
  vim.schedule(function()
    on_lines(nil, nil, nil, 0, 1)
  end)

  -- Register attach
  vim.api.nvim_buf_attach(prompt_bufnr, true, {
    on_lines = vim.schedule_wrap(on_lines),

    on_detach = function(...)
      -- print("DETACH:", ...)
    end,
  })


  -- TODO: Use WinLeave as well?
  local on_buf_leave = string.format(
    [[  autocmd BufLeave <buffer> ++nested ++once :lua require('telescope.pickers').on_close_prompt(%s)]],
    prompt_bufnr)

  vim.cmd([[augroup PickerInsert]])
  vim.cmd([[  au!]])
  vim.cmd(    on_buf_leave)
  vim.cmd([[augroup END]])

  self.prompt_bufnr = prompt_bufnr

  local prompt_border_win = prompt_opts.border and prompt_opts.border.win_id
  local results_border_win = results_opts.border and results_opts.border.win_id
  local preview_border_win = preview_opts and preview_opts.border and preview_opts.border.win_id

  if prompt_border_win then vim.api.nvim_win_set_option(prompt_border_win, 'winhl', 'Normal:TelescopeNormal') end
  if results_border_win then vim.api.nvim_win_set_option(results_border_win, 'winhl', 'Normal:TelescopeNormal') end
  if preview_border_win then vim.api.nvim_win_set_option(preview_border_win, 'winhl', 'Normal:TelescopeNormal') end

  state.set_status(prompt_bufnr, {
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
    previewer = self.previewer,
    finder = finder,
  })

  mappings.apply_keymap(prompt_bufnr, self.attach_mappings, default_mappings)

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


function Picker:close_windows(status)
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
      vim.cmd(string.format("bdelete! %s", bufnr))
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

local ns_telescope_selection = a.nvim_create_namespace('telescope_selection')

function Picker:get_selection()
  return self._selection
end

function Picker:get_selection_row()
  return self._selection_row or self.max_results
end

function Picker:move_selection(change)
  self:set_selection(self:get_selection_row() + change)
end

function Picker:reset_selection()
  self._selection = nil
  self._selection_row = nil
end

function Picker:set_selection(row)
  -- TODO: Loop around behavior?
  -- TODO: Scrolling past max results
  if row > self.max_results then
    row = self.max_results
  elseif row < 1 then
    row = 1
  end

  if not self:can_select_row(row) then
    log.info("Cannot select row:", row, self.manager:num_results(), self.max_results)
    return
  end

  -- local entry = self.manager:get_entry(self.max_results - row + 1)
  local entry = self.manager:get_entry(self:get_index(row))
  local status = state.get_status(self.prompt_bufnr)
  local results_bufnr = status.results_bufnr

  if not vim.api.nvim_buf_is_valid(results_bufnr) then
    return
  end

  -- TODO: Probably should figure out what the rows are that made this happen...
  --        Probably something with setting a row that's too high for this?
  --        Not sure.
  local set_ok, set_errmsg = pcall(function()
    -- Handle adding '> ' to beginning of selections
    if self._selection_row then
      local old_selection = a.nvim_buf_get_lines(results_bufnr, self._selection_row, self._selection_row + 1, false)[1]

      if old_selection then
        a.nvim_buf_set_lines(results_bufnr, self._selection_row, self._selection_row + 1, false, {'  ' .. old_selection:sub(3)})
      end
    end

    a.nvim_buf_set_lines(results_bufnr, row, row + 1, false, {'> ' .. (a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1] or ''):sub(3)})

    a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)
    a.nvim_buf_add_highlight(
      results_bufnr,
      ns_telescope_selection,
      'TelescopeSelection',
      row,
      0,
      -1
    )
  end)

  if not set_ok then
    log.debug(set_errmsg)
    return
  end

  -- if self._match_id then
  --   -- vim.fn.matchdelete(self._match_id)
  --   vim.fn.clearmatches(results_win)
  -- end

  -- self._match_id = vim.fn.matchaddpos("Conceal", { {row + 1, 1, 2} }, 0, -1, { window = results_win, conceal = ">" })
  if self._selection == entry and self._selection_row == row then
    return
  end

  -- TODO: Don't let you go over / under the buffer limits
  -- TODO: Make sure you start exactly at the bottom selected

  -- TODO: Get row & text in the same obj
  self._selection = entry
  self._selection_row = row

  if status.preview_win and self.previewer then
    self.previewer:preview(
      entry,
      status
    )
  end
end

function Picker:close_existing_pickers()
  for _, prompt_bufnr in ipairs(state.get_existing_prompts()) do
    actions.close(prompt_bufnr)
  end
end


pickers.new = function(opts, defaults)
  opts = extend(opts, defaults)
  return Picker:new(opts)
end

-- TODO: We should consider adding `process_bulk` or `bulk_entry_manager` for things
-- that we always know the items and can score quickly, so as to avoid drawing so much.
pickers.entry_manager = function(max_results, set_entry, info)
  log.debug("Creating entry_manager...")

  info = info or {}
  info.looped = 0
  info.inserted = 0

  -- state contains list of
  --    {
  --        score = ...
  --        line = ...
  --        metadata ? ...
  --    }
  local entry_state = {}

  set_entry = set_entry or function() end

  local worst_acceptable_score = math.huge

  return setmetatable({
    add_entry = function(self, score, entry)
      score = score or 0

      if score >= worst_acceptable_score then
        return
      end

      for index, item in ipairs(entry_state) do
        info.looped = info.looped + 1

        if item.score > score then
          return self:insert(index, {
            score = score,
            entry = entry,
          })
        end

        -- Don't add results that are too bad.
        if index >= max_results then
          return
        end
      end

      return self:insert({
        score = score,
        entry = entry,
      })
    end,

    insert = function(self, index, entry)
      if entry == nil then
        entry = index
        index = #entry_state + 1
      end

      -- To insert something, we place at the next available index (or specified index)
      -- and then shift all the corresponding items one place.
      local next_entry, last_score
      repeat
        info.inserted = info.inserted + 1 
        next_entry = entry_state[index]

        set_entry(index, entry.entry)
        entry_state[index] = entry

        last_score = entry.score

        index = index + 1
        entry = next_entry

      until not next_entry or index > max_results

      if index > max_results then
        worst_acceptable_score = last_score
      end
    end,

    num_results = function()
      return #entry_state
    end,

    get_ordinal = function(self, index)
      return self:get_entry(index).ordinal
    end,

    get_entry = function(_, index)
      return (entry_state[index] or {}).entry
    end,

    get_score = function(_, index)
      return (entry_state[index] or {}).score
    end,

    find_entry = function(_, entry)
      if entry == nil then
        return nil
      end

      for k, v in ipairs(entry_state) do
        local existing_entry = v.entry

        -- FIXME: This has the problem of assuming that display will not be the same for two different entries.
        if existing_entry.display == entry.display then
          return k
        end
      end

      return nil
    end,

    _get_state = function()
      return entry_state
    end,
  }, {})
end


function pickers.on_close_prompt(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker

  if picker.previewer then
    picker.previewer:teardown()
  end

  picker:close_windows(status)
end

pickers._Picker = Picker


return pickers
