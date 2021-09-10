local fn = vim.fn
local extension_module = require "telescope._extensions"
local extension_info = require("telescope").extensions
local is_win = vim.api.nvim_call_function("has", { "win32" }) == 1

local health_start = vim.fn["health#report_start"]
local health_ok = vim.fn["health#report_ok"]
local health_warn = vim.fn["health#report_warn"]
local health_error = vim.fn["health#report_error"]
local health_info = vim.fn["health#report_info"]

local optional_dependencies = {
  {
    finder_name = "live-grep",
    package = {
      {
        name = "rg",
        url = "[BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep)",
        optional = false,
      },
    },
  },
  {
    finder_name = "find-files",
    package = {
      {
        name = "fd",
        url = "[sharkdp/fd](https://github.com/sharkdp/fd)",
        optional = true,
      },
    },
  },
}

local required_plugins = {
  { lib = "plenary", optional = false },
  {
    lib = "nvim-treesitter",
    optional = true,
    info = "",
  },
}

local check_binary_installed = function(package)
  local file_extension = is_win and ".exe" or ""
  local filename = package.name .. file_extension
  if fn.executable(filename) == 0 then
    return
  else
    local handle = io.popen(filename .. " --version")
    local binary_version = handle:read "*a"
    handle:close()
    return true, binary_version
  end
end

local function lualib_installed(lib_name)
  local res, _ = pcall(require, lib_name)
  return res
end

local M = {}

M.check_health = function()
  -- Required lua libs
  health_start "Checking for required plugins"
  for _, plugin in ipairs(required_plugins) do
    if lualib_installed(plugin.lib) then
      health_ok(plugin.lib .. " installed.")
    else
      local lib_not_installed = plugin.lib .. " not found."
      if plugin.optional then
        health_warn(("%s %s"):format(lib_not_installed, plugin.info))
      else
        health_error(lib_not_installed)
      end
    end
  end

  -- external dependencies
  -- TODO: only perform checks if user has enabled dependency in their config
  health_start "Checking external dependencies"

  for _, opt_dep in pairs(optional_dependencies) do
    for _, package in ipairs(opt_dep.package) do
      local installed, version = check_binary_installed(package)
      if not installed then
        local err_msg = ("%s: not found."):format(package.name)
        if package.optional then
          health_warn(("%s %s"):format(err_msg, ("Install %s for extended capabilities"):format(package.url)))
        else
          health_error(
            ("%s %s"):format(
              err_msg,
              ("`%s` finder will not function without %s installed."):format(opt_dep.finder_name, package.url)
            )
          )
        end
      else
        local eol = version:find "\n"
        health_ok(("%s: found %s"):format(package.name, version:sub(0, eol - 1) or "(unknown version)"))
      end
    end
  end

  -- Extensions
  health_start "===== Installed extensions ====="

  local installed = {}
  for extension_name, _ in pairs(extension_info) do
    installed[#installed + 1] = extension_name
  end
  table.sort(installed)

  for _, installed_ext in ipairs(installed) do
    local extension_healthcheck = extension_module._health[installed_ext]

    health_start(string.format("Telescope Extension: `%s`", installed_ext))
    if extension_healthcheck then
      extension_healthcheck()
    else
      health_info "No healthcheck provided"
    end
  end
end

return M
