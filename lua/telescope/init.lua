local _extensions = require "telescope._extensions"

local telescope = {}

-- TODO: Add pre to the works
-- ---@pre [[
-- ---@pre ]]

---@brief [[
--- Telescope.nvim is a plugin for fuzzy finding and neovim. It helps you search,
--- filter, find and pick things in Lua.
---
--- <pre>
--- To find out more:
--- https://github.com/nvim-telescope/telescope.nvim
---
---   :h telescope.setup
---   :h telescope.builtin
---   :h telescope.layout
---   :h telescope.actions
--- </pre>
---@brief ]]

---@tag telescope.nvim

--- Setup function to be run by user. Configures the defaults, extensions
--- and other aspects of telescope.
---@param opts table: Configuration opts. Keys: defaults, extensions
---@eval { ["description"] = require('telescope').__format_setup_keys() }
function telescope.setup(opts)
  opts = opts or {}

  if opts.default then
    error "'default' is not a valid value for setup. See 'defaults'"
  end

  require("telescope.config").set_defaults(opts.defaults)
  require("telescope.config").set_pickers(opts.pickers)
  _extensions.set_config(opts.extensions)
end

--- Register an extension. To be used by plugin authors.
---@param mod table: Module
function telescope.register_extension(mod)
  return _extensions.register(mod)
end

--- Load an extension.
---@param name string: Name of the extension
function telescope.load_extension(name)
  return _extensions.load(name)
end

--- Use telescope.extensions to reference any extensions within your configuration. <br>
--- While the docs currently generate this as a function, it's actually a table. Sorry.
telescope.extensions = require("telescope._extensions").manager

telescope.__format_setup_keys = function()
  local descriptions = require("telescope.config").descriptions

  local names = vim.tbl_keys(descriptions)
  table.sort(names)

  local result = { "<pre>", "", "Valid keys for {opts.defaults}" }
  for _, name in ipairs(names) do
    local desc = descriptions[name]

    table.insert(result, "")
    table.insert(result, string.format("%s*telescope.defaults.%s*", string.rep(" ", 70 - 20 - #name), name))
    table.insert(result, string.format("%s: ~", name))
    for _, line in ipairs(vim.split(desc, "\n")) do
      table.insert(result, string.format("    %s", line))
    end
  end

  table.insert(result, "</pre>")
  return result
end

return telescope
