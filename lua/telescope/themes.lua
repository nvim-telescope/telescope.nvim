-- Prototype Theme System (WIP)
-- Currently certain designs need a number of parameters.
--
-- local opts = themes.get_dropdown { winblend = 3 }
--

local themes = {}

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
    width = function(_,max_columns,_)
      return math.min(max_columns-3,80)
    end,
    results_height = function(_,_,max_lines)
      return math.min(max_lines-4,15)
    end,
    borderchars = {
      { '─', '│', '─', '│', '╭', '╮', '╯', '╰'},
      prompt = {"─", "│", " ", "│", "╭", "╮", "│", "│"},
      results = {"─", "│", "─", "│", "├", "┤", "╯", "╰"},
      preview = { '─', '│', '─', '│', '╭', '╮', '╯', '╰'},
    },
  }

  return vim.tbl_deep_extend("force", theme_opts, opts)
end

return themes
