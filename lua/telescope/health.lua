local health = vim.health

local extension_module = require "telescope._extensions"
local extension_info = require("telescope").extensions
local is_win = vim.api.nvim_call_function("has", { "win32" }) == 1

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
        binaries = { "fdfind", "fd" },
        url = "[sharkdp/fd](https://github.com/sharkdp/fd)",
        optional = true,
      },
    },
  },
}

local required_plugins = {
  { lib = "plenary", optional = false },
}

local check_binary_installed = function(package)
  local binaries = package.binaries or { package.name }
  for _, binary in ipairs(binaries) do
    local found = vim.fn.executable(binary) == 1
    if not found and is_win then
      binary = binary .. ".exe"
      found = vim.fn.executable(binary) == 1
    end
    if found then
      local handle = io.popen(binary .. " --version")
      local binary_version = handle:read "*a"
      handle:close()
      return true, binary_version
    end
  end
end

local function lualib_installed(lib_name)
  local res, _ = pcall(require, lib_name)
  return res
end

local M = {}

M.check = function()
  -- Required lua libs
  health.start "Checking for required plugins"
  for _, plugin in ipairs(required_plugins) do
    if lualib_installed(plugin.lib) then
      health.ok(plugin.lib .. " installed.")
    else
      local lib_not_installed = plugin.lib .. " not found."
      if plugin.optional then
        health.warn(("%s %s"):format(lib_not_installed, plugin.info))
      else
        health.error(lib_not_installed)
      end
    end
  end

  -- external dependencies
  -- TODO: only perform checks if user has enabled dependency in their config
  health.start "Checking external dependencies"

  for _, opt_dep in pairs(optional_dependencies) do
    for _, package in ipairs(opt_dep.package) do
      local installed, version = check_binary_installed(package)
      if not installed then
        local err_msg = ("%s: not found."):format(package.name)
        if package.optional then
          health.warn(("%s %s"):format(err_msg, ("Install %s for extended capabilities"):format(package.url)))
        else
          health.error(
            ("%s %s"):format(
              err_msg,
              ("`%s` finder will not function without %s installed."):format(opt_dep.finder_name, package.url)
            )
          )
        end
      else
        local eol = version:find "\n"
        local ver = eol and version:sub(0, eol - 1) or "(unknown version)"
        health.ok(("%s: found %s"):format(package.name, ver))
      end
    end
  end

  -- Extensions
  health.start "===== Installed extensions ====="

  local installed = {}
  for extension_name, _ in pairs(extension_info) do
    installed[#installed + 1] = extension_name
  end
  table.sort(installed)

  for _, installed_ext in ipairs(installed) do
    local extension_healthcheck = extension_module._health[installed_ext]

    health.start(string.format("Telescope Extension: `%s`", installed_ext))
    if extension_healthcheck then
      extension_healthcheck()
    else
      health.info "No healthcheck provided"
    end
  end
end

return M
