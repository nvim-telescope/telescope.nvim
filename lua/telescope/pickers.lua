local a = vim.api
local popup = require('popup')

local mappings = require('telescope.mappings')
local state = require('telescope.state')
local utils = require('telescope.utils')

local pickers = {}

local Picker = {}
Picker.__index = Picker

function Picker:new(opts)
  opts = opts or {}
  return setmetatable({
    filter = opts.filter,
    previewer = opts.previewer,
    maps = opts.maps,
  }, Picker)
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

  local width = 100
  local col = 10
  local prompt_line = 50

  local result_height = 25
  local prompt_height = 1

  -- TODO: Add back the borders after fixing some stuff in popup.nvim
  local results_win, results_opts = popup.create('', {
    height = result_height,
    minheight = result_height,
    width = width,
    line = prompt_line - 2 - result_height,
    col = col,
    border = {},
    enter = false,
  })
  local results_bufnr = a.nvim_win_get_buf(results_win)

  local preview_win, preview_opts = popup.create('', {
    height = result_height + prompt_height + 2,
    minheight = result_height + prompt_height + 2,
    width = 100,
    line = prompt_line - 2 - result_height,
    col = col + width + 2,
    border = {},
    enter = false,
    highlight = false,
  })
  local preview_bufnr = a.nvim_win_get_buf(preview_win)

  -- TODO: For some reason, highlighting is kind of weird on these windows.
  --        It may actually be my colorscheme tho...
  a.nvim_win_set_option(preview_win, 'winhl', 'Normal:Normal')

  -- TODO: We need to center this and make it prettier...
  local prompt_win, prompt_opts = popup.create('', {
    height = prompt_height,
    width = width,
    line = prompt_line,
    col = col,
    border = {},
    title = prompt_string
  })
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)

  -- a.nvim_buf_set_option(prompt_bufnr, 'buftype', 'prompt')
  -- vim.fn.prompt_setprompt(prompt_bufnr, prompt_string)

  local on_lines = function(_, _, _, first_line, last_line)
    local prompt = vim.api.nvim_buf_get_lines(prompt_bufnr, first_line, last_line, false)[1]

    vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})

    -- Create a closure that has all the data we need
    -- We pass a function called "newResult" to get_results
    --    get_results calles "newResult" every time it gets a new result
    --    picker then (if available) calls sorter
    --    and then appropriately places new result in the buffer.

    local line_scores = {}

    -- TODO: We need to fix the sorting
    -- TODO: We should provide a simple fuzzy matcher in Lua for people
    -- TODO: We should get all the stuff on the bottom line directly, not floating around
    -- TODO: We need to handle huge lists in a good way, cause currently we'll just put too much stuff in the buffer
    -- TODO: Stop having things crash if we have an error.
    finder(prompt, function(line)
      if sorter then
        local sort_score = sorter:score(prompt, line)
        if sort_score == -1 then
          return
        end

        -- { 7, 3, 1, 1 }
        -- 2
        for row, row_score in utils.reversed_ipairs(line_scores) do
          if row_score > sort_score then
            -- Insert line at row
            vim.api.nvim_buf_set_lines(results_bufnr, row, row, false, {
              string.format("%s // %s %s", line, sort_score, row)
            })

            -- Insert current score in the table
            table.insert(line_scores, row + 1, sort_score)

            -- All done :)
            return
          end
        end

        -- Worst score so far, so add to end
        vim.api.nvim_buf_set_lines(results_bufnr, -1, -1, false, {line})
        table.insert(line_scores, sort_score)
      else
        -- Just always append to the end of the buffer if this is all you got.
        vim.api.nvim_buf_set_lines(results_bufnr, -1, -1, false, {line})
      end
    end)
    -- local results = finder:get_results(results_win, results_bufnr, line)
  end

  -- Call this once to pre-populate if it makes sense
  vim.schedule_wrap(on_lines(nil, nil, nil, 0, 1))

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

  -- print(vim.inspect(state.get_status(prompt_bufnr)))
  mappings.set_keymap(prompt_bufnr, results_bufnr)

  vim.cmd [[startinsert]]
end

function Picker:close_windows(status)
  -- vim.fn['popup#close_win'](state.prompt_win)
  -- vim.fn['popup#close_win'](state.results_win)
  -- vim.fn['popup#close_win'](state.preview_win)
  local prompt_win = status.prompt_win
  local results_win = status.results_win
  local preview_win = status.preview_win

  local prompt_border_win = status.prompt_border_win
  local results_border_win = status.results_border_win
  local preview_border_win = status.preview_border_win

  local function del_win(name, win_id, force)
    local file = io.open("/home/tj/test.txt", "a")
    file:write(string.format("Closing.... %s %s\n", name, win_id))
    local ok = pcall(vim.api.nvim_win_close, win_id, force)
    file:write(string.format("OK: %s\n", ok))
    file:write("...Done\n\n")
    file:close()
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



pickers.new = function(...)
  return Picker:new(...)
end

return pickers
