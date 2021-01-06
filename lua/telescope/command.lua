local themes = require('telescope.themes')
local builtin = require('telescope.builtin')
local extensions = require('telescope._extensions').manager
local command = {}

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

  if string.len(theme) > 0 then
    opts = themes[theme](opts)
  end

  if string.len(extension_type) > 0 then
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
