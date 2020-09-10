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

  set("selection_strategy", "reset")

  set("layout_strategy", "horizontal")
  set("width", 0.75)
  set("winblend", 0)

  set("border", {})
  set("borderchars", { '─', '│', '─', '│', '╭', '╮', '╯', '╰'})

  -- Builtin configuration

  -- List that will be executed.
  --    Last argument will be the search term (passed in during execution)
  set("vimgrep_arguments", {'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column'})

  -- TODO: Shortenpath
  --    Decide how to propagate that to all the opts everywhere.

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
