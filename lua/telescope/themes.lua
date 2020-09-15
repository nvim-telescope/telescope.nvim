-- Prototype Theme System
-- Currently certain designs need a number of parameters.
--
-- local opts = GetTheme("dropdown", { winblend = 3 })
-- 

local Theme = {}
Theme.__index = Theme

local merge = function(table1, table2)
  for k, v in pairs(table2) do table1[k] = v end

  return table1
end

function Theme:new(opts)
  opts = opts or {}

  return setmetatable({
    layout_strategy = opts.layout_strategy,
    border = opts.border,
    sorting_strategy = opts.sorting_strategy,
    prompt = opts.prompt,
    results_title = opts.results_title,
    preview_title = opts.preview_title,
    borderchars = opts.borderchars,
  }, Theme)
end

function Theme:get_opts()
  return self
end

-- Get the opts from the theme
-- This will be defaults the theme will use to make the
-- layout.
local get_opts = function(theme)
  return {
    sorting_strategy = "ascending",
    layout_strategy = "center",
    border = false,
    results_title = "",
    preview_title = "Preview",
    prompt = "",
    borderchars = {"", "", "", "", "", "", "", ""},
  }
end

function GetTheme(theme_name, opts)
  local theme_opts = get_opts(theme_name)

  local theme = Theme:new(merge(theme_opts, opts))

  return theme
end

return Theme
