require('telescope._compat')

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
  if opts.default then
    error("'default' is not a valid value for setup. See 'defaults'")
  end

  require('telescope.config').set_defaults(opts.defaults)
end

return telescope
