-- TODO: Debounce preview window maybe
-- TODO: Make filters
--          "fzf --filter"
--           jobstart() -> | fzf --filter "input on prompt"

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local state = require('telescope.state')

local telescope = {
  finders = finders,
  pickers = pickers,
  previewers = previewers,
  state = state,
}

function __TelescopeOnLeave(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker

  picker:close_windows(status)
end

-- TODO: Probably could attach this with nvim_buf_attach, and then I don't have to do the ugly global function stuff
function __TelescopeOnChange(prompt_bufnr, prompt, results_bufnr, results_win)
  local line = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)[1]
  local prompt_input = string.sub(line, #prompt + 1)

  local status = state.get_status(prompt_bufnr)
  local finder = status.finder

  vim.api.nvim_buf_set_lines(results_bufnr, 0, -1, false, {})
  local results = finder:get_results(results_win, results_bufnr, prompt_input)
end

return telescope
