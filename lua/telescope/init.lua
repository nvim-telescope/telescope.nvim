require('telescope._compat')

local _extensions = require('telescope._extensions')

local telescope = {}

function telescope.setup(opts)
  opts = opts or {}

  if opts.default then
    error("'default' is not a valid value for setup. See 'defaults'")
  end

  require('telescope.config').set_defaults(opts.defaults)
  _extensions.set_config(opts.extensions)
end

function telescope.register_extension(mod)
  return _extensions.register(mod)
end

function telescope.load_extension(name)
  return _extensions.load(name)
end

--- Use telescope.extensions to reference any extensions within your configuration.
telescope.extensions = require('telescope._extensions').manager

return telescope
