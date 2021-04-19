-- Prototype Theme System (WIP)
-- Currently certain designs need a number of parameters.
--
-- local opts = themes.get_dropdown { winblend = 3 }

---@tag telescope.themes

---@brief [[
--- Themes are ways to combine several elements of styling together.
---
--- They are helpful for managing the several differnt UI aspects for telescope and provide
--- a simple interface for users to get a particular "style" of picker.
---@brief ]]

local themes = {}

--- Dropdown style theme.
--- <pre>
---
--- Usage:
---
---     `local builtin = require('telescope.builtin')`
---     `local themes = require('telescope.themes')`
---     `builtin.find_files(themes.get_dropdown())`
--- </pre>
function themes.get_dropdown(opts)
  opts = opts or {}

  local theme_opts = {
    -- WIP: Decide on keeping these names or not.
    theme = "dropdown",

    sorting_strategy = "ascending",
    layout_strategy = "center",
    results_title = false,
    preview_title = "Preview",
    preview_cutoff = 1, -- Preview should always show (unless previewer = false)
    width = 80,
    results_height = 15,
    borderchars = {
      { "─", "│", "─", "│", "╭", "╮", "╯", "╰"},
      prompt = {"─", "│", " ", "│", "╭", "╮", "│", "│"},
      results = {"─", "│", "─", "│", "├", "┤", "╯", "╰"},
      preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰"},
    },
  }

  return vim.tbl_deep_extend("force", theme_opts, opts)
end

--- Ivy style theme.
--- <pre>
---
--- Usage:
---
---     `local builtin = require('telescope.builtin')`
---     `local themes = require('telescope.themes')`
---     `builtin.find_files(themes.get_ivy())`
--- </pre>
function themes.get_ivy(opts)
  opts = opts or {}

  return vim.tbl_deep_extend("force", {
    theme = "ivy",

    sorting_strategy = "ascending",

    preview_title = "",

    layout_strategy = "bottom_pane",
    layout_config = {
      height = 25,
    },

    border = true,
    borderchars = {
      "z",
      prompt = { "─", " ", " ", " ", "─", "─", " ", " " },
      results = { " " },
      -- results = { "a", "b", "c", "d", "e", "f", "g", "h" },
      preview = { "─", "│", "─", "│", "╭", "╮", "╯", "╰"},
    },
  }, opts)
end

return themes
