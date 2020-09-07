
local opts_manager = {}

-- Could use cool metatable to do this automatically
-- Idk, I have some other thoughts.
opts_manager.shorten_path = function(opts)
  if opts.shorten_path ~= nil then
    return opts.shorten_path
  elseif config.values.shorten_path ~= nil then
    return config.values.shorten_path
  else
    return true
  end
end


return opts_manager
