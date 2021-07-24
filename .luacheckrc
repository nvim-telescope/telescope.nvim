-- Rerun tests only if their modification time changed.
cache = true

std = luajit
codes = true

self = false

-- Glorious list of warnings: https://luacheck.readthedocs.io/en/stable/warnings.html
ignore = {
  -- Unused argument/variable starting with _
  "211/_.*",
  "212/_.*",
  "213/_.*",
  "122", -- Indirectly setting a readonly global
}

globals = {
  "_",
  "TelescopeGlobalState",
  "TelescopeCachedUppers",
  "TelescopeCachedTails",
  "TelescopeCachedNgrams",
  "_TelescopeConfigurationValues",
  "_TelescopeConfigurationPickers",
  "__TelescopeKeymapStore",
}

-- Global objects defined by the C code
read_globals = {
  "vim",
}

-- vim: set filetype=lua :
