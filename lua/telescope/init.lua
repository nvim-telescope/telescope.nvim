package.loaded['popup'] = nil
package.loaded['popup.border'] = nil
package.loaded['popup.init'] = nil

local a = vim.api

local popup = require('popup')

local telescope = {}

local ns_telescope = a.nvim_create_namespace('telescope')
local ns_telescope_highlight = a.nvim_create_namespace('telescope_highlight')

local Finder = {}
Finder.__index = Finder

function Finder:new(fn_command)
  -- TODO: Add config for:
  --        - cwd
  return setmetatable({
    fn_command = fn_command,
    job_id = -1,
  }, Finder)
end

function Finder:display_results(win, bufnr, prompt)
  if self.job_id > 0 then
    -- Make sure we kill old jobs.
    vim.fn.jobstop(self.job_id)
  end

  self.job_id = vim.fn.jobstart(self.fn_command(prompt), {
    -- TODO: Decide if we want this or don't want this.
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      a.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    end,

    on_exit = function()
      -- TODO: Add possibility to easily highlight prompt within buffer
      -- without having to do weird stuff and with it actually working...
      if false then
        vim.fn.matchadd("Type", "\\<" .. prompt .. "\\>", 1, -1, {window = win})
      end
    end,
  })

  --[[
  local function get_rg_results(bufnr, search_string)
    local start_time = vim.fn.reltime()

    vim.fn.jobstart(string.format('rg %s', search_string), {
      cwd = '/home/tj/build/neovim',

      on_stdout = function(job_id, data, event)
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
      end,

      on_exit = function()
        print("Finished in: ", vim.fn.reltimestr(vim.fn.reltime(start_time)))
      end,

      stdout_buffer = true,
    })
  end
  --]]
end

local Previewer = {}
Previewer.__index = Previewer

function Previewer:new(fn)
  return setmetatable({
    fn = fn,
  }, Previewer)
end

local picker_finders = {}

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

local hack_status = {}

local previewers = {}

function Picker:find(finder)
  local prompt_string = 'MUNITER > '
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
  local results_win = popup.create('', {
    height = result_height,
    minheight = result_height,
    width = width,
    line = prompt_line - 2 - result_height,
    col = col,
    -- border = {},
    enter = false,
  })
  local results_bufnr = a.nvim_win_get_buf(results_win)
  picker_finders[results_bufnr] = finder

  local preview_win = popup.create('', {
    height = result_height + prompt_height + 4,
    minheight = result_height + prompt_height + 4,
    width = 100,
    line = prompt_line - 2 - result_height,
    col = col + width + 2,
    -- border = {},
    enter = false,
    highlight = false,
  })
  local preview_bufnr = a.nvim_win_get_buf(preview_win)

  -- TODO: For some reason, highlighting is kind of weird on these windows.
  --        It may actually be my colorscheme tho...
  a.nvim_win_set_option(preview_win, 'winhl', '')

  -- TODO: We need to center this and make it prettier...
  local prompt_win = popup.create('', {
    height = prompt_height,
    width = width,
    line = prompt_line,
    col = col,
    border = {},
  })
  local prompt_bufnr = a.nvim_win_get_buf(prompt_win)

  a.nvim_buf_set_option(prompt_bufnr, 'buftype', 'prompt')
  vim.fn.prompt_setprompt(prompt_bufnr, prompt_string)

  -- TODO: Please use the cool autocmds once you get off your lazy bottom and finish the PR ;)
  local autocmd_string = string.format(
    [[  autocmd TextChanged,TextChangedI <buffer> :lua __TelescopeOnChange(%s, "%s", %s, %s)]],
    prompt_bufnr,
    prompt_string,
    results_bufnr,
    results_win)

  local buf_close = string.format(
    [[  autocmd BufLeave <buffer> :bd! %s ]],
    prompt_bufnr)

  local results_close = string.format(
    [[ autocmd BufLeave <buffer> :call nvim_win_close(%s, v:true) ]],
    results_win)

  local preview_close = string.format(
    [[ autocmd BufLeave <buffer> :call nvim_win_close(%s, v:true) ]],
    preview_win)

  vim.cmd([[augroup PickerCommands]])
  vim.cmd([[  au!]])
  vim.cmd(    autocmd_string)
  vim.cmd(    buf_close)
  vim.cmd(    results_close)
  vim.cmd(    preview_close)
  vim.cmd([[augroup END]])

  previewers[prompt_bufnr] = self.previewer

  -- TODO: Clear this hack status stuff when closing
  hack_status[prompt_bufnr] = {
    prompt_bufnr = prompt_bufnr,
    prompt_win = prompt_win,
    results_bufnr = results_bufnr,
    results_win = results_win,
    preview_bufnr = preview_bufnr,
    preview_win = preview_win,
  }

  local function default_mapper(map_key, table_key)
    a.nvim_buf_set_keymap(
      prompt_bufnr,
      'i',
      map_key,
      string.format(
        [[<C-O>:lua __TelescopeMapping(%s, %s, '%s')<CR>]],
        prompt_bufnr,
        results_bufnr,
        table_key
        ),
      {
        silent = true,
      }
    )
  end

  default_mapper('<c-n>', 'control-n')
  default_mapper('<c-p>', 'control-p')
  default_mapper('<CR>', 'enter')

  vim.cmd [[startinsert]]
end

-- TODO: All lower case mappings
local telescope_selections = {}

local function update_current_selection(prompt_bufnr, results_bufnr, row)
  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_highlight, 0, -1)
  a.nvim_buf_add_highlight(
    results_bufnr,
    ns_telescope_highlight,
    'Error',
    row,
    0,
    -1
  )

  telescope_selections[prompt_bufnr] = row

  if previewers[prompt_bufnr] then
    vim.g.got_here = true
    local status = hack_status[prompt_bufnr]
    previewers[prompt_bufnr].fn(
      status.preview_win,
      status.preview_bufnr,
      status.results_bufnr,
      row
    )
  end
end

local mappings = {}

-- TODO: Refactor this to use shared code.
-- TODO: Move from top to bottom, etc.
-- TODO: It seems like doing this brings us back to the beginning of the prompt, which is not great.
mappings["control-n"] = function(prompt_bufnr, results_bufnr)
  if telescope_selections[prompt_bufnr] == nil then
    telescope_selections[prompt_bufnr] = 0
  end

  local row = telescope_selections[prompt_bufnr] + 1
  update_current_selection(prompt_bufnr, results_bufnr, row)
end

mappings["control-p"] = function(prompt_bufnr, results_bufnr)
  if telescope_selections[prompt_bufnr] == nil then
    telescope_selections[prompt_bufnr] = 0
  end

  local row = telescope_selections[prompt_bufnr] - 1
  update_current_selection(prompt_bufnr, results_bufnr, row)
end

mappings["enter"] = function(prompt_bufnr, results_bufnr)
  local extmark = a.nvim_buf_get_extmarks(
    results_bufnr,
    ns_telescope_highlight,
    0,
    -1,
    {}
  )

  print(vim.inspect(extmark))
end

function __TelescopeMapping(prompt_bufnr, results_bufnr, characters)
  if mappings[characters] then
    mappings[characters](prompt_bufnr, results_bufnr)
  end
end

function __TelescopeOnChange(bufnr, prompt, results_bufnr, results_win)
  local line = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
  local prompt_input = string.sub(line, #prompt + 1)
  print(string.format("|%s|", prompt_input))

  local finder = picker_finders[results_bufnr]
  a.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
  finder:display_results(results_win, results_bufnr, prompt_input)
end

-- Uhh, finder should probably just GET the results
-- and then update some table.
-- When updating the table, we should call filter on those items
-- and then only display ones that pass the filter
local f = Finder:new(function(prompt)
  return string.format('rg %s', prompt)
end)

local p = Picker:new {
  previewer = Previewer:new(function(preview_win, preview_bufnr, results_bufnr, row)
    local line = a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
    local file_name = vim.split(line, ":")[1]

    -- print(file_name)
    -- vim.fn.termopen(
    --   string.format("bat --color=always --style=grid %s"),
    local file_bufnr = vim.fn.bufnr(file_name, true)
    -- TODO: We should probably call something like this because we're not always getting highlight and all that stuff.
    -- api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filename))
    a.nvim_win_set_buf(preview_win, file_bufnr)
  end)
}
p:find(f)

-- TODO: Make filters
-- "fzf --filter"
--  jobstart() -> | fzf --filter "input on prompt"
-- function Filter:new(command)
-- end

return telescope
