local log = require('telescope.log')

local path = {}

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

-- In most cases it is better to use `utils.path_shorten`
-- as it handles cases for `len` being things other than
-- a positive integer.
path.shorten = function(filepath,len)
  return require'plenary.path'.new(filepath):shorten(len)
end

path.normalize = function(filepath, cwd)
  filepath = path.make_relative(filepath, cwd)

  -- Substitute home directory w/ "~"
  filepath = filepath:gsub("^" .. path.home, '~', 1)

  -- Remove double path separators, it's annoying
  filepath = filepath:gsub(path.separator .. path.separator, path.separator)

  return filepath
end

path.read_file = function(filepath)
  local fd = vim.loop.fs_open(filepath, "r", 438)
  if fd == nil then return '' end
  local stat = assert(vim.loop.fs_fstat(fd))
  if stat.type ~= 'file' then return '' end
  local data = assert(vim.loop.fs_read(fd, stat.size, 0))
  assert(vim.loop.fs_close(fd))
  return data
end

path.read_file_async = function(filepath, callback)
  vim.loop.fs_open(filepath, "r", 438, function(err_open, fd)
    if err_open then
      print("We tried to open this file but couldn't. We failed with following error message: " .. err_open)
      return
    end
    vim.loop.fs_fstat(fd, function(err_fstat, stat)
      assert(not err_fstat, err_fstat)
      if stat.type ~= 'file' then return callback('') end
      vim.loop.fs_read(fd, stat.size, 0, function(err_read, data)
        assert(not err_read, err_read)
        vim.loop.fs_close(fd, function(err_close)
          assert(not err_close, err_close)
          return callback(data)
        end)
      end)
    end)
  end)
end

return setmetatable({}, {
  __index = function(_, k)
    log.error("telescope.path is deprecated. please use plenary.path instead")
    return path[k]
  end
})
