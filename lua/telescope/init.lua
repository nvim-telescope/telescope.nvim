local telescope = {}

--[[
local actions = require('telescope.actions')

require('telescope').setup {
  defaults = {
    -- Picker Configuration
    border = {},
    borderchars = { '─', '│', '─', '│', '┌', '┐', '┘', '└'},
    preview_cutoff = 120,
    selection_strategy = "reset",

    -- Can choose EITHER one of these:
    layout_strategy = "horizontal",

    get_window_options = function(...) end,

    default_mappings = {
      i = {
        ["<C-n>"] = actions.move_selection_next,
        ["<C-p>"] = actions.move_selection_previous,
      },

      n = {
        ["<esc>"] = actions.close,
        ["<CR>"] = actions.goto_file_selection_edit,
      },
    },

    shorten_path = true,

    winblend = 10, -- help winblend

    winblend = {
      preview = 0,
      prompt = 20,
      results = 20,
    },

  },
}

--]]

function telescope.setup(opts)
  require('telescope.config').set_defaults(opts.defaults)
end

-- Until I have better profiling stuff, this will have to do.
PERF = function(...) end
PERF_DEBUG = PERF_DEBUG or nil
START = nil

if PERF_DEBUG then
  PERF = function(...)
    local new_time = (vim.loop.hrtime() - START) / 1E9
    if select('#', ...) == 0 then
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(PERF_DEBUG, -1, -1, false, { '' })
      end)
      return
    end

    local to_insert = ''
    if START then
      to_insert = tostring(new_time) .. ' | '
    end

    for _, v in ipairs({...}) do
      if type(v) == 'table' then
        to_insert = to_insert .. tostring(#v) .. ' | '
      else
        to_insert = to_insert .. tostring(v) .. ' | '
      end
    end

    vim.schedule(function()
      vim.api.nvim_buf_set_lines(PERF_DEBUG, -1, -1, false, { to_insert })
    end)
  end
end

return telescope
