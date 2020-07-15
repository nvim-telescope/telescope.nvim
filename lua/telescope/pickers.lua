local a = vim.api
local popup = require('popup')

local mappings = require('telescope.mappings')
local state = require('telescope.state')

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


function Picker:find(finder)
  local prompt_string = 'Find File'
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

  vim.api.nvim_buf_attach(prompt_bufnr, true, {
    on_lines = vim.schedule_wrap(function(_, _, _, first_line, last_line)
      local line = vim.api.nvim_buf_get_lines(prompt_bufnr, first_line, last_line, false)[1]

      vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
      local results = finder:get_results(results_win, results_bufnr, line)
    end),

    on_detach = function(...)
      -- print("DETACH:", ...)
    end,
  })

  -- -- TODO: Please use the cool autocmds once you get off your lazy bottom and finish the PR ;)
  -- local autocmd_string = string.format(
  --   [[  autocmd TextChanged,TextChangedI <buffer> :lua __TelescopeOnChange(%s, "%s", %s, %s)]],
  --   prompt_bufnr,
  --   '',
  --   results_bufnr,
  --   results_win)

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
