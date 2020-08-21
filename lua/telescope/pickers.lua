local a = vim.api
local popup = require('popup')


local log = require('telescope.log')
local mappings = require('telescope.mappings')
local state = require('telescope.state')
local utils = require('telescope.utils')

local pickers = {}

--- Picker is the main UI that shows up to interact w/ your results.
-- Takes a filter & a previewr
local Picker = {}
Picker.__index = Picker


local Sorter = require('telescope.sorters').Sorter
local Previewer = require('telescope.previewers').Previewer

assert(Sorter)
assert(Previewer)

---@class PickOpts
---@field filter Sorter
---@field maps table
---@field unseen string

--- Create new picker
--- @param opts PickOpts
function Picker:new(opts)
  return setmetatable({
    filter = opts.filter,
    previewer = opts.previewer,
    maps = opts.maps,
  }, Picker)
end

function Picker._get_window_options(max_columns, max_lines, prompt_title)
  local preview = {
    border = {},
    enter = false,
    highlight = false
  }
  local results = {
    border = {},
    enter = false,
  }
  local prompt = {
    title = prompt_title,
    border = {},
    enter = true
  }

  local width_padding = 10
  if max_columns < 200 then
    preview.width = 80
  else
    preview.width = 120
  end

  local other_width = max_columns - preview.width - (2 * width_padding)
  results.width = other_width
  prompt.width = other_width

  results.height = 25
  results.minheight = results.height
  prompt.height = 1
  prompt.minheight = prompt.height

  preview.height = results.height + prompt.height + 2
  preview.minheight = preview.height

  results.col = width_padding
  prompt.col = width_padding
  preview.col = results.col + results.width + 2

  local height_padding = math.floor(0.95 * max_lines)
  results.line = max_lines - height_padding
  prompt.line = results.line + results.height + 2
  preview.line = results.line

  return {
    preview = preview,
    results = results,
    prompt = prompt,
  }
end

function Picker:find(opts)
  opts = opts or {}

  local finder = opts.finder
  assert(finder, "Finder is required to do picking")

  local sorter = opts.sorter

  local prompt_string = opts.prompt

  -- Create three windows:
  -- 1. Prompt window
  -- 2. Options window
  -- 3. Preview window
  local popup_opts = Picker._get_window_options(vim.o.columns, vim.o.lines, prompt_string)

  -- TODO: Add back the borders after fixing some stuff in popup.nvim
  local results_win, results_opts = popup.create('', popup_opts.results)
  local results_bufnr = a.nvim_win_get_buf(results_win)

  local preview_win, preview_opts = popup.create('', popup_opts.preview)
  local preview_bufnr = a.nvim_win_get_buf(preview_win)

  -- TODO: For some reason, highlighting is kind of weird on these windows.
  --        It may actually be my colorscheme tho...
  a.nvim_win_set_option(preview_win, 'winhl', 'Normal:Normal')
  a.nvim_win_set_option(preview_win, 'winblend', 1)

  -- TODO: We need to center this and make it prettier...
  local prompt_win, prompt_opts = popup.create('', popup_opts.prompt)
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)

  -- a.nvim_buf_set_option(prompt_bufnr, 'buftype', 'prompt')
  -- vim.fn.prompt_setprompt(prompt_bufnr, prompt_string)

  -- First thing we want to do is set all the lines to blank.
  self.max_results = popup_opts.results.height - 1
  local initial_lines = {}
  for _ = 1, self.max_results do table.insert(initial_lines, "") end
  vim.api.nvim_buf_set_lines(results_bufnr, 0, self.max_results, false, initial_lines)

  local on_lines = function(_, _, _, first_line, last_line)
    local prompt = vim.api.nvim_buf_get_lines(prompt_bufnr, first_line, last_line, false)[1]

    -- Create a closure that has all the data we need
    -- We pass a function called "newResult" to get_results
    --    get_results calles "newResult" every time it gets a new result
    --    picker then (if available) calls sorter
    --    and then appropriately places new result in the buffer.

    -- TODO: We need to fix the sorting
    -- TODO: We should provide a simple fuzzy matcher in Lua for people
    -- TODO: We should get all the stuff on the bottom line directly, not floating around
    -- TODO: We need to handle huge lists in a good way, cause currently we'll just put too much stuff in the buffer
    -- TODO: Stop having things crash if we have an error.

    local line_manager = pickers.line_manager(
      self.max_results,
      function(index, line)
        local row = self.max_results - index + 1

        log.trace("Setting row", row, "with value", line)
        vim.api.nvim_buf_set_lines(results_bufnr, row, row + 1, false, {line})
      end
    )

    local process_result = function(line)
      if vim.trim(line) == "" then
        return
      end

      log.trace("Processing result... ", line)

      local sort_score = 0
      if sorter then
        sort_score = sorter:score(prompt, line)
        if sort_score == -1 then
          log.trace("Filtering out result: ", line)
          return
        end
      end

      line_manager:add_result(sort_score, line)
    end

    local process_complete = function()
      local worst_line = self.max_results - line_manager.num_results()
      local empty_lines = utils.repeated_table(worst_line, "")
      -- vim.api.nvim_buf_set_lines(results_bufnr, 0, worst_line + 1, false, empty_lines)

      log.debug("Worst Line after process_complete: %s", worst_line, results_bufnr)

      -- local fun = require('fun')
      -- local zip = fun.zip
      -- local tomap = fun.tomap

      -- log.trace("%s", tomap(zip(
      --   a.nvim_buf_get_lines(results_bufnr, worst_line, self.max_results, false),
      --   self.line_scores
      -- )))
    end

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
    [[  autocmd BufLeave <buffer> ++nested ++once :lua __TelescopeOnLeave(%s)]],
    prompt_bufnr)

  vim.cmd([[augroup PickerInsert]])
  vim.cmd([[  au!]])
  vim.cmd(    on_buf_leave)
  vim.cmd([[augroup END]])

  self.prompt_bufnr = prompt_bufnr

  state.set_status(prompt_bufnr, {
    prompt_bufnr = prompt_bufnr,
    prompt_win = prompt_win,
    prompt_border_win = prompt_opts.border.win_id,

    results_bufnr = results_bufnr,
    results_win = results_win,
    results_border_win = results_opts.border.win_id,

    preview_bufnr = preview_bufnr,
    preview_win = preview_win,
    preview_border_win = preview_opts.border.win_id,

    picker = self,
    previewer = self.previewer,
    finder = finder,
  })

  mappings.set_keymap(prompt_bufnr, results_bufnr)

  vim.cmd [[startinsert]]
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
  return self.selection or self.max_results
end

function Picker:move_selection(change)
  self:set_selection(self:get_selection() + change)
end

function Picker:set_selection(row)
  if row > self.max_results then
    row = self.max_results
  elseif row < 1 then
    row = 1
  end

  local status = state.get_status(self.prompt_bufnr)

  a.nvim_buf_clear_namespace(status.results_bufnr, ns_telescope_selection, 0, -1)
  a.nvim_buf_add_highlight(
    status.results_bufnr,
    ns_telescope_selection,
    'Error',
    row,
    0,
    -1
  )

  -- TODO: Don't let you go over / under the buffer limits
  -- TODO: Make sure you start exactly at the bottom selected

  -- TODO: Get row & text in the same obj
  self.selection = row

  if self.previewer then
    self.previewer:preview(
      status.preview_win,
      status.preview_bufnr,
      status.results_bufnr,
      row
    )
  end
end

pickers.new = function(...)
  return Picker:new(...)
end

-- TODO: We should consider adding `process_bulk` or `bulk_line_manager` for things
-- that we always know the items and can score quickly, so as to avoid drawing so much.
pickers.line_manager = function(max_results, set_line)
  log.debug("Creating line_manager...")

  -- state contains list of
  --    {
  --        score = ...
  --        line = ...
  --        metadata ? ...
  --    }
  local state = {}

  set_line = set_line or function() end

  return setmetatable({
    add_result = function(self, score, line)
      score = score or 0

      for index, item in ipairs(state) do
        if item.score > score then
          return self:insert(index, {
            score = score,
            line = line,
          })
        end

        -- Don't add results that are too bad.
        if index >= max_results then
          return self
        end
      end

      return self:insert({
        score = score,
        line = line,
      })
    end,

    insert = function(self, index, item)
      if item == nil then
        item = index
        index = #state + 1
      end

      -- To insert something, we place at the next available index (or specified index)
      -- and then shift all the corresponding items one place.
      local next_item
      repeat
        next_item = state[index]

        set_line(index, item.line)
        state[index] = item

        index = index + 1
        item = next_item
      until not next_item
    end,

    num_results = function()
      return #state
    end,

    _get_state = function()
      return state
    end,
  }, {
    -- insert =

    -- __index = function(_, line)
    -- end,

    -- __newindex = function(_, index, line)
    -- end,
  })
end


return pickers
