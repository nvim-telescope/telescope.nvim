local themes = require('telescope.themes')
local builtin = require('telescope.builtin')
local extensions = require('telescope._extensions').manager
local config = require('telescope.config')
local command = {}

local bool_type = {
  ['false'] = false,
  ['true'] = true
}

-- convert command line string arguments to
-- lua number boolean type and nil value
local function convert_user_opts(user_opts)
  local default_opts = config.values

  local _switch = {
    ['boolean'] = function(key,val)
      if val == 'false' then
        user_opts[key] = false
      end
      user_opts[key] = true
    end,
    ['number'] = function(key,val)
      user_opts[key] = tonumber(val)
    end,
    ['string'] = function(key,val)
      if val == 'nil' then
        user_opts[key] = nil
      end
      if val == '""' then
        user_opts[key] = ''
      end
      if val == '"' then
        user_opts[key] = ''
      end
      if bool_type[val] ~= nil then
        user_opts[key] = bool_type[val]
      end
    end
  }

  local _switch_metatable = {
    __index = function(_,k)
      print(string.format('Type of %s does not match',k))
    end
  }

  setmetatable(_switch,_switch_metatable)

  for key,val in pairs(user_opts) do
    if default_opts[key] ~= nil then
      _switch[type(default_opts[key])](key,val)
    else
      _switch['string'](key,val)
    end
  end
end

-- receive the viml command args
-- it should be a table value like
-- {
--   cmd = 'find_files',
--   theme = 'dropdown',
--   extension_type  = 'command'
--   opts = {
--      cwd = '***',
-- }
function command.run_command(args)
  local user_opts = args or {}
  if next(user_opts) == nil and not user_opts.cmd then
    print('[Telescope] your command miss args')
    return
  end

  local cmd = user_opts.cmd
  local opts = user_opts.opts or {}
  local extension_type = user_opts.extension_type or ''
  local theme = user_opts.theme or ''

  if next(opts) ~= nil then
    convert_user_opts(opts)
  end

  if string.len(theme) > 0 then
    opts = themes[theme](opts)
  end

  if string.len(extension_type) > 0 and extension_type ~= '"' then
    extensions[cmd][extension_type](opts)
    return
  end

  if builtin[cmd] then
    builtin[cmd](opts)
    return
  end

  if rawget(extensions,cmd) then
    extensions[cmd][cmd](opts)
  end
end

return command
