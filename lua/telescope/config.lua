local get_default = require('telescope.utils').get_default


-- TODO: Add other major configuration points here.
-- border
-- borderchars
-- selection_strategy

-- TODO: use `require('telescope').setup { }`

_TelescopeConfigurationValues = _TelescopeConfigurationValues or {}

_TelescopeConfigurationValues.default_layout_strategy = get_default(
  _TelescopeConfigurationValues.default_layout_strategy,
  'horizontal'
)

-- TODO: this should probably be more complicated than just a number.
--  If you're going to allow a bunch of layout strats, they should have nested info or something
_TelescopeConfigurationValues.default_window_width = get_default(
  _TelescopeConfigurationValues.default_window_width,
  0.75
)

return _TelescopeConfigurationValues
