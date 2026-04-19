--- Path.lua
---
--- Goal: Create objects that are extremely similar to Python's `Path` Objects.
--- Reference: https://docs.python.org/3/library/pathlib.html

local uv = vim.uv
local fs = vim.fs

---@class Path
---@field filename string
local Path = {}

local check_self = function(self)
  if type(self) == "string" then
    return Path:new(self)
  end

  return self
end

Path.__index = function(t, k)
  local raw = rawget(Path, k)
  if raw then
    return raw
  end

  if k == "_cwd" then
    local cwd = uv.fs_realpath "."
    t._cwd = cwd
    return cwd
  end

  if k == "_absolute" then
    local absolute = uv.fs_realpath(t.filename)
    t._absolute = absolute
    return absolute
  end
end

Path.__tostring = function(self)
  return fs.normalize(self.filename)
end

Path.is_path = function(a)
  return getmetatable(a) == Path
end

function Path:new(...)
  local args = { ... }

  if type(self) == "string" then
    table.insert(args, 1, self)
    self = Path -- luacheck: ignore
  end

  local path_input
  if #args == 1 then
    path_input = args[1]
  else
    path_input = args
  end

  -- If we already have a Path, it's fine.
  --   Just return it
  if Path.is_path(path_input) then
    return path_input
  end

  local path_string
  if type(path_input) == "table" then
    -- TODO: It's possible this could be done more elegantly with __concat
    --       But I'm unsure of what we'd do to make that happen
    local path_objs = {}
    for _, v in ipairs(path_input) do
      if Path.is_path(v) then
        table.insert(path_objs, v.filename)
      else
        assert(type(v) == "string")
        table.insert(path_objs, v)
      end
    end

    local pathsep = vim.fn.has "win32" == 1 and "\\" or "/"
    path_string = table.concat(path_objs, pathsep)
  else
    assert(type(path_input) == "string", vim.inspect(path_input))
    path_string = path_input
  end

  local obj = {
    filename = path_string,
  }

  setmetatable(obj, Path)

  return obj
end

function Path:_fs_filename()
  return self:absolute() or self.filename
end

function Path:_stat()
  return uv.fs_stat(self:_fs_filename()) or {}
end

function Path:absolute()
  return fs.abspath(self.filename)
end

function Path:exists()
  return not vim.tbl_isempty(self:_stat())
end

function Path:make_relative(cwd)
  return fs.relpath(cwd, self.filename) or self.filename
end

function Path:normalize(_)
  return fs.normalize(self.filename)
end

function Path:is_file()
  return self:_stat().type == "file" and true or nil
end

-- TODO: Asyncify this and use vim.wait in the meantime.
--  This will allow other events to happen while we're waiting!
function Path:_read()
  self = check_self(self)

  local fd = assert(uv.fs_open(self:_fs_filename(), "r", 438)) -- for some reason test won't pass with absolute
  local stat = assert(uv.fs_fstat(fd))
  local data = assert(uv.fs_read(fd, stat.size, 0))
  assert(uv.fs_close(fd))

  return data
end

function Path:touch(opts)
  opts = opts or {}

  local mode = opts.mode or 420
  local parents = vim.F.if_nil(opts.parents, false, opts.parents)

  if self:exists() then
    local new_time = os.time()
    uv.fs_utime(self:_fs_filename(), new_time, new_time)
    return
  end

  if parents then
    vim.fn.mkdir(fs.dirname(self.filename), "p")
  end

  local fd = uv.fs_open(self:_fs_filename(), "w", mode)
  if not fd then
    error("Could not create file: " .. self:_fs_filename())
  end
  uv.fs_close(fd)

  return true
end

function Path:_read_async(callback)
  uv.fs_open(self.filename, "r", 438, function(err_open, fd)
    if err_open then
      print("We tried to open this file but couldn't. We failed with following error message: " .. err_open)
      return
    end
    uv.fs_fstat(fd, function(err_fstat, stat)
      assert(not err_fstat, err_fstat)
      if stat.type ~= "file" then
        return callback ""
      end
      uv.fs_read(fd, stat.size, 0, function(err_read, data)
        assert(not err_read, err_read)
        uv.fs_close(fd, function(err_close)
          assert(not err_close, err_close)
          return callback(data)
        end)
      end)
    end)
  end)
end

function Path:read(callback)
  if callback then
    return self:_read_async(callback)
  end
  return self:_read()
end

function Path:readlines()
  self = check_self(self)

  local data = self:read()

  data = data:gsub("\r", "")
  return vim.split(data, "\n")
end

function Path:readbyterange(offset, length)
  self = check_self(self)

  local fd = uv.fs_open(self:_fs_filename(), "r", 438)
  if not fd then
    return
  end
  local stat = assert(uv.fs_fstat(fd))
  if stat.type ~= "file" then
    uv.fs_close(fd)
    return nil
  end

  if offset < 0 then
    offset = stat.size + offset
    -- Windows fails if offset is < 0 even though offset is defined as signed
    -- http://docs.libuv.org/en/v1.x/fs.html#c.uv_fs_read
    if offset < 0 then
      offset = 0
    end
  end

  local data = ""
  while #data < length do
    local read_chunk = assert(uv.fs_read(fd, length - #data, offset))
    if #read_chunk == 0 then
      break
    end
    data = data .. read_chunk
    offset = offset + #read_chunk
  end

  assert(uv.fs_close(fd))

  return data
end

return Path
