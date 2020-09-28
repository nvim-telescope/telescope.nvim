local path = {}

-- TODO: Can we use vim.loop for this?
path.separator = package.config:sub(1, 1)
path.home = vim.fn.expand("~")


path.make_relative = function(filepath, cwd)
  if not cwd or not filepath then return filepath end

  if filepath:sub(1, #cwd) == cwd  then
    local offset =  0
    -- if  cwd does ends in the os separator, we need to take it off
    if cwd:sub(#cwd, #cwd) ~= path.separator then
      offset = 1
    end

    filepath = filepath:sub(#cwd + 1 + offset, #filepath)
  end

  return filepath
end

path.shorten = (function()
  if jit then
    local ffi = require('ffi')
    ffi.cdef [[
    typedef unsigned char char_u;
    char_u *shorten_dir(char_u *str);
    ]]

    return function(filepath)
      if not filepath then
        return filepath
      end

      local c_str = ffi.new("char[?]", #filepath + 1)
      ffi.copy(c_str, filepath)
      return ffi.string(ffi.C.shorten_dir(c_str))
    end
  else
    return function(filepath)
      return filepath
    end
  end
end)()

path.normalize = function(filepath, cwd)
  filepath = path.make_relative(filepath, cwd)

  -- Substitute home directory w/ "~"
  filepath = filepath:gsub("^" .. path.home, '~', 1)

  -- Remove double path separators, it's annoying
  filepath = filepath:gsub(path.separator .. path.separator, path.separator)

  return filepath
end

return path
