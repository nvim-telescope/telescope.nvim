-- Rerun tests only if their modification time changed.
cache = true

std = "luajit"
codes = true
self = false

-- Ignore specific warnings.
ignore = {
  "212", -- Unused argument (valid for callbacks)
  "122", -- Indirectly setting a readonly global
}

-- Global identifiers allowed
globals = {
  "_",
  "TelescopeGlobalState",
  "_TelescopeConfigurationValues",
  "_TelescopeConfigurationPickers",
}

-- Globals defined by Neovim host
read_globals = {
  "vim",
}

files = {
  ["lua/telescope/builtin/init.lua"] = {
    ignore = {
      "631", -- ignore long lines >120 chars
    }
  },
}
