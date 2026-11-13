local health = vim.health

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

local check_binary_installed = function(package)
  local binaries = package.binaries or { package.name }
  for _, binary in ipairs(binaries) do
    if vim.fn.executable(binary) == 1 then
      return true, vim.system({ binary, "--version" }):wait().stdout
    end
  end
end

local M = {}

M.check = function()
  health.start "Checking Neovim version"
  if vim.fn.has "nvim-0.13" == 1 then
    health.ok(("Nvim %s"):format(tostring(vim.version())))
  else
    health.error(("Nvim %s: telescope requires Nvim 0.13 or later"):format(tostring(vim.version())))
    return
  end
  if jit then
    health.ok(("Built with %s"):format(jit.version))
  else
    health.warn("Not built with LuaJIT: sorting and filtering will be much slower", "Use a build with LuaJIT")
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
        local ver = version and version:match "^(.-)\n" or "(unknown version)"
        health.ok(("%s: found %s"):format(package.name, ver))
      end
    end
  end

  -- Extensions
  health.start "===== Installed extensions ====="

  local extension_module = require "telescope._extensions"
  local installed = {}
  for extension_name, _ in pairs(require("telescope").extensions) do
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
