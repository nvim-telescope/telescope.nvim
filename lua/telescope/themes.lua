-- Prototype Theme System (WIP)
-- Currently certain designs need a number of parameters.
--
-- local opts = themes.get_dropdown { winblend = 3 }
--

local themes = {}

function themes.get_dropdown(opts)
  local theme_opts = {
    -- WIP: Decide on keeping these names or not.
    theme = "dropdown",

    sorting_strategy = "ascending",
    layout_strategy = "center",
    results_title = false,
    preview_title = "Preview",
    border = false,
    borderchars = {
      prompt = {"─", "│", " ", "│", "╭", "╮", "│", "│"},
      results = {"─", "│", "─", "│", "├", "┤", "╯", "╰"},
      preview = {"=", "=", "", "", "", "", "", ""}
    },
  }

  return vim.tbl_deep_extend("force", theme_opts, opts)
end

return themes
