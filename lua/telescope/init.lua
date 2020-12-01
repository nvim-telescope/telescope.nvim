require('telescope._compat')

local _extensions = require('telescope._extensions')

local telescope = {}

-- TODO: Add pre to the works
-- ---@pre [[
-- ---@pre ]]

---@brief [[
--- Telescope.nvim is a plugin for fuzzy finding and neovim. It helps you search
--- for anything you can imagine (and then write in Lua).
---@brief ]]
---@tag telescope.nvim

--- Setup function to be run by user. Configures the defaults, extensions
--- and other aspects of telescope.
---@param opts table: Configuration opts. Keys: defaults, extensions
function telescope.setup(opts)
  opts = opts or {}

  if opts.default then
    error("'default' is not a valid value for setup. See 'defaults'")
  end

  require('telescope.config').set_defaults(opts.defaults)
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

--- Use telescope.extensions to reference any extensions within your configuration.
--- While the docs currently generate this as a function, it's actually a table. Sorry.
telescope.extensions = require('telescope._extensions').manager

return telescope
