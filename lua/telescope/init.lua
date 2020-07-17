-- TODO: Debounce preview window maybe
-- TODO: Make filters
--          "fzf --filter"
--           jobstart() -> | fzf --filter "input on prompt"

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local state = require('telescope.state')

local telescope = {
  -- <module>.new { }
  finders = finders,
  pickers = pickers,
  previewers = previewers,
  sorters = sorters,

  state = state,
}

function __TelescopeOnLeave(prompt_bufnr)
  local status = state.get_status(prompt_bufnr)
  local picker = status.picker

  picker:close_windows(status)
end

return telescope
