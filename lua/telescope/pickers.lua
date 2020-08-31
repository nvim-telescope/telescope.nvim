local a = vim.api
local popup = require('popup')
local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

local actions = require('telescope.actions')
local log = require('telescope.log')
local mappings = require('telescope.mappings')
local state = require('telescope.state')
local utils = require('telescope.utils')

local Entry = require('telescope.entry')

local get_default = utils.get_default

-- TODO: Make this work with deep extend I think.
local extend = function(opts, defaults)
  local result = vim.deepcopy(opts or {})
  for k, v in pairs(defaults or {}) do
    if result[k] == nil then
      result[k] = v
    end
  end

  return result
end

local pickers = {}

local default_mappings = {
  i = {
    ["<C-n>"] = actions.move_selection_next,
    ["<C-p>"] = actions.move_selection_previous,
    ["<CR>"] = actions.goto_file_selection,
  },

  n = {
    ["<esc>"] = actions.close,
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

  return setmetatable({
    prompt = opts.prompt,

    finder = opts.finder,
    sorter = opts.sorter,
    previewer = opts.previewer,

    mappings = get_default(opts.mappings, default_mappings),

    get_window_options = opts.get_window_options,
    selection_strategy = opts.selection_strategy,

    window = {
      -- TODO: This won't account for different layouts...
      height = get_default(opts.height, 0.8),
      preview_width = get_default(opts.preview_width, 0.8),
      results_width = get_default(opts.results_width, 0.8),

      -- Border config
      border = get_default(opts.border, {}),
      borderchars = get_default(opts.borderchars, { '─', '│', '─', '│', '┌', '┐', '┘', '└'}),
    },

    preview_cutoff = get_default(opts.preview_cutoff, 120),
  }, Picker)
end

function Picker:get_window_options(max_columns, max_lines, prompt_title)
  local popup_border = self.window.border
  local popup_borderchars = self.window.borderchars

  local preview = {
    border = popup_border,
    borderchars = popup_borderchars,
    enter = false,
    highlight = false
  }

  local results = {
    border = popup_border,
    borderchars = popup_borderchars,
    enter = false,
  }

  local prompt = {
    title = prompt_title,
    border = popup_border,
    borderchars = popup_borderchars,
    enter = true
  }

  -- TODO: Test with 120 width terminal

  local width_padding = 10
  if not self.previewer or max_columns < self.preview_cutoff then
    width_padding = 2
    preview.width = 0
  elseif max_columns < 150 then
    width_padding = 5
    preview.width = math.floor(max_columns * 0.4)
  elseif max_columns < 200 then
    preview.width = 80
  else
    preview.width = 120
  end

  local other_width = max_columns - preview.width - (2 * width_padding)
  results.width = other_width
  prompt.width = other_width

  local base_height
  if max_lines < 40 then
    base_height = math.min(math.floor(max_lines * 0.8), max_lines - 8)
  else
    base_height = math.floor(max_lines * 0.8)
  end
  results.height = base_height
  results.minheight = results.height
  prompt.height = 1
  prompt.minheight = prompt.height

  if self.previewer then
    preview.height = results.height + prompt.height + 2
    preview.minheight = preview.height
  else
    preview.height = 0
  end

  results.col = width_padding
  prompt.col = width_padding
  preview.col = results.col + results.width + 2

  -- TODO: Center this in the page a bit better.
  local height_padding = math.max(math.floor(0.95 * max_lines), 2)
  results.line = max_lines - height_padding
  prompt.line = results.line + results.height + 2
  preview.line = results.line

  return {
    preview = preview.width > 0 and preview,
    results = results,
    prompt = prompt,
  }
end

function Picker:find()
  local prompt_string = assert(self.prompt, "Prompt is required.")
  local finder = assert(self.finder, "Finder is required to do picking")
  local sorter = self.sorter

  self.original_win_id = a.nvim_get_current_win()

  -- Create three windows:
  -- 1. Prompt window
  -- 2. Options window
  -- 3. Preview window
  local popup_opts = self:get_window_options(vim.o.columns, vim.o.lines, prompt_string)

  -- TODO: Add back the borders after fixing some stuff in popup.nvim
  local results_win, results_opts = popup.create('', popup_opts.results)
  local results_bufnr = a.nvim_win_get_buf(results_win)

  -- TODO: Should probably always show all the line for results win, so should implement a resize for the windows
  a.nvim_win_set_option(results_win, 'wrap', false)


  local preview_win, preview_opts, preview_bufnr
  if popup_opts.preview then
    preview_win, preview_opts = popup.create('', popup_opts.preview)
    preview_bufnr = a.nvim_win_get_buf(preview_win)

    -- TODO: For some reason, highlighting is kind of weird on these windows.
    --        It may actually be my colorscheme tho...
    a.nvim_win_set_option(preview_win, 'winhl', 'Normal:Normal')
    a.nvim_win_set_option(preview_win, 'winblend', 10)
  end

  -- TODO: We need to center this and make it prettier...
  local prompt_win, prompt_opts = popup.create('', popup_opts.prompt)
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)

  -- a.nvim_buf_set_option(prompt_bufnr, 'buftype', 'prompt')
  -- vim.fn.prompt_setprompt(prompt_bufnr, prompt_string)

  -- First thing we want to do is set all the lines to blank.
  self.max_results = popup_opts.results.height - 1

  vim.api.nvim_buf_set_lines(results_bufnr, 0, self.max_results, false, utils.repeated_table(self.max_results, ""))

  local selection_strategy = self.selection_strategy or 'reset'

  local on_lines = function(_, _, _, first_line, last_line)
    local prompt = vim.api.nvim_buf_get_lines(prompt_bufnr, first_line, last_line, false)[1]

    self.manager = pickers.entry_manager(
      self.max_results,
      vim.schedule_wrap(function(index, entry)
        local row = self.max_results - index + 1

        -- If it's less than 0, then we don't need to show it at all.
        if row < 0 then
          return
        end

        -- TODO: This really isn't the place to do this.
        local display = entry.display

        if has_devicons then
          local icon = devicons.get_icon(display, vim.fn.fnamemodify(display, ":e"))
          display = (icon or ' ') .. ' ' ..  display
        end

        display = '  ' .. display

        -- log.info("Setting row", row, "with value", entry)
        vim.api.nvim_buf_set_lines(results_bufnr, row, row + 1, false, {display})
      end
    ))

    local process_result = function(line)
      local entry = Entry:new(line)

      if not entry.valid then
        return
      end

      log.info("Processing result... ", entry)

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
          log.trace("Filtering out result: ", entry)
          return
        end
      end

      self.manager:add_entry(sort_score, entry)
    end

    local process_complete = vim.schedule_wrap(function()
      if selection_strategy == 'row' then
        self:set_selection(self:get_selection_row())
      elseif selection_strategy == 'follow' then
        local index = self.manager:find_entry(self:get_selection())

        if index then
          local follow_row = self.max_results - index + 1
          self:set_selection(follow_row)
        else
          self:set_selection(self.max_results)
        end
      else
        -- selection_strategy == 'reset'
        self:set_selection(self.max_results)
      end

      local worst_line = self.max_results - self.manager.num_results()
      if worst_line <= 0 then
        return
      end

      local empty_lines = utils.repeated_table(worst_line, "")
      vim.api.nvim_buf_set_lines(results_bufnr, 0, worst_line, false, empty_lines)

      log.trace("Worst Line after process_complete: %s", worst_line, results_bufnr)
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

  state.set_status(prompt_bufnr, {
    prompt_bufnr = prompt_bufnr,
    prompt_win = prompt_win,
    prompt_border_win = prompt_opts.border and prompt_opts.border.win_id,

    results_bufnr = results_bufnr,
    results_win = results_win,
    results_border_win = results_opts.border and results_opts.border.win_id,

    preview_bufnr = preview_bufnr,
    preview_win = preview_win,
    preview_border_win = preview_opts and preview_opts.border and preview_opts.border.win_id,
    picker = self,
    previewer = self.previewer,
    finder = finder,
  })

  mappings.apply_keymap(prompt_bufnr, self.mappings)

  vim.cmd [[startinsert]]
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

  local function del_win(name, win_id, force)
    if not vim.api.nvim_win_is_valid(win_id) then
      return
    end

    if not pcall(vim.api.nvim_win_close, win_id, force) then
      log.trace("Unable to close window: %s/%s", name, win_id)
    end
  end

  del_win("prompt_win", prompt_win, true)
  del_win("results_win", results_win, true)
  del_win("preview_win", preview_win, true)

  del_win("prompt_border_win", prompt_border_win, true)
  del_win("results_border_win", results_border_win, true)
  del_win("preview_border_win", preview_border_win, true)

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

function Picker:set_selection(row)
  if row > self.max_results then
    row = self.max_results
  elseif row < 1 then
    row = 1
  end

  local entry = self.manager:get_entry(self.max_results - row + 1)
  if entry == self._selection and row == self._selection_row then
    log.trace("Same entry as before. Skipping set")
    return
  end

  local status = state.get_status(self.prompt_bufnr)
  local results_bufnr = status.results_bufnr

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

  -- if self._match_id then
  --   -- vim.fn.matchdelete(self._match_id)
  --   vim.fn.clearmatches(results_win)
  -- end

  -- self._match_id = vim.fn.matchaddpos("Conceal", { {row + 1, 1, 2} }, 0, -1, { window = results_win, conceal = ">" })

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

pickers.new = function(opts, defaults)
  opts = extend(opts, defaults)
  return Picker:new(opts)
end

-- TODO: We should consider adding `process_bulk` or `bulk_entry_manager` for things
-- that we always know the items and can score quickly, so as to avoid drawing so much.
pickers.entry_manager = function(max_results, set_entry)
  log.debug("Creating entry_manager...")

  -- state contains list of
  --    {
  --        score = ...
  --        line = ...
  --        metadata ? ...
  --    }
  local entry_state = {}

  set_entry = set_entry or function() end

  return setmetatable({
    add_entry = function(self, score, entry)
      -- TODO: Consider forcing people to make these entries before we add them.
      if type(entry) == "string" then
        entry = Entry:new(entry)
      end

      score = score or 0

      for index, item in ipairs(entry_state) do
        if item.score > score then
          return self:insert(index, {
            score = score,
            entry = entry,
          })
        end

        -- Don't add results that are too bad.
        if index >= max_results then
          return self
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
      local next_entry
      repeat
        next_entry = entry_state[index]

        set_entry(index, entry.entry)
        entry_state[index] = entry

        index = index + 1
        entry = next_entry
      until not next_entry
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

  picker:close_windows(status)
end


return pickers
