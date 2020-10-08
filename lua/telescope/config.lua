-- Keep the values around between reloads
_TelescopeConfigurationValues = _TelescopeConfigurationValues or {}

local function first_non_null(...)
  local n = select('#', ...)
  for i = 1, n do
    local value = select(i, ...)

    if value ~= nil then
      return value
    end
  end
end

local actions = require('telescope.actions')

-- TODO: Add other major configuration points here.
-- selection_strategy

local config = {}

config.values = _TelescopeConfigurationValues

function config.set_defaults(defaults)
  defaults = defaults or {}

  local function get(name, default_val)
    return first_non_null(defaults[name], config.values[name], default_val)
  end

  local function set(name, default_val)
    config.values[name] = get(name, default_val)
  end

  set("sorting_strategy", "descending")
  set("selection_strategy", "reset")

  set("layout_strategy", "horizontal")
  set("layout_options", {})

  set("width", 0.75)
  set("winblend", 0)
  set("prompt_position", "bottom")
  set("preview_cutoff", 120)

  set("results_height", 1)
  set("results_width", 0.8)

  set("border", {})
  set("borderchars", { '─', '│', '─', '│', '╭', '╮', '╯', '╰'})

  set("get_status_text", function(self) return string.format("%s / %s", self.stats.processed - self.stats.filtered, self.stats.processed) end)

  -- Builtin configuration

  -- List that will be executed.
  --    Last argument will be the search term (passed in during execution)
  set("vimgrep_arguments", {'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column', '--smart-case'})

  -- TODO: Shortenpath
  --    Decide how to propagate that to all the opts everywhere.

  -- TODO: Add motions to keybindings
  -- TODO: Add relative line numbers?
  set("default_mappings", {
    i = {
      ["<C-n>"] = actions.move_selection_next,
      ["<C-p>"] = actions.move_selection_previous,

      ["<C-c>"] = actions.close,

      ["<Down>"] = actions.move_selection_next,
      ["<Up>"] = actions.move_selection_previous,

      ["<CR>"] = actions.goto_file_selection_edit,
      ["<C-x>"] = actions.goto_file_selection_split,
      ["<C-v>"] = actions.goto_file_selection_vsplit,
      ["<C-t>"] = actions.goto_file_selection_tabedit,

      ["<C-u>"] = actions.preview_scrolling_up,
      ["<C-d>"] = actions.preview_scrolling_down,

      -- TODO: When we implement multi-select, you can turn this back on :)
      -- ["<Tab>"] = actions.add_selection,
    },

    n = {
      ["<esc>"] = actions.close,
      ["<CR>"] = actions.goto_file_selection_edit,
      ["<C-x>"] = actions.goto_file_selection_split,
      ["<C-v>"] = actions.goto_file_selection_vsplit,
      ["<C-t>"] = actions.goto_file_selection_tabedit,

      -- TODO: This would be weird if we switch the ordering.
      ["j"] = actions.move_selection_next,
      ["k"] = actions.move_selection_previous,

      ["<Down>"] = actions.move_selection_next,
      ["<Up>"] = actions.move_selection_previous,

      ["<C-u>"] = actions.preview_scrolling_up,
      ["<C-d>"] = actions.preview_scrolling_down,
    },
  })


  -- NOT STABLE. DO NOT USE
  set("horizontal_config", {
    get_preview_width = function(columns, _)
      return math.floor(columns * 0.75)
    end,
  })
end

function config.clear_defaults()
  for k, _ in pairs(config.values) do
    config.values[k] = nil
  end
end

config.set_defaults()


return config
