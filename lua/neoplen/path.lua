--- Path.lua
---
--- Goal: Create objects that are extremely similar to Python's `Path` Objects.
--- Reference: https://docs.python.org/3/library/pathlib.html

local uv = vim.uv

local F = vim.F

local S_IF = {
  -- S_IFDIR  = 0o040000  # directory
  DIR = 0x4000,
  -- S_IFREG  = 0o100000  # regular file
  REG = 0x8000,
}

local path = {}

path.home = uv.os_homedir()

path.sep = (function()
  if jit then
    local os = string.lower(jit.os)
    if os ~= "windows" then
      return "/"
    else
      return "\\"
    end
  else
    return package.config:sub(1, 1)
  end
end)()

path.root = (function()
  if path.sep == "/" then
    return function()
      return "/"
    end
  else
    return function(base)
      base = base or uv.cwd()
      return base:sub(1, 1) .. ":\\"
    end
  end
end)()

path.S_IF = S_IF

local function is_root(pathname)
  if path.sep == "\\" then
    return string.match(pathname, "^[A-Z]:\\?$")
  end
  return pathname == "/"
end

local _split_by_separator = (function()
  local formatted = string.format("([^%s]+)", path.sep)
  return function(filepath)
    local t = {}
    for str in string.gmatch(filepath, formatted) do
      table.insert(t, str)
    end
    return t
  end
end)()

local is_uri = function(filename)
  return string.match(filename, "^%a[%w+-.]*://") ~= nil
end

local is_absolute = function(filename, sep)
  if sep == "\\" then
    return string.match(filename, "^[%a]:[\\/].*$") ~= nil
  end
  return string.sub(filename, 1, 1) == sep
end

local function _normalize_path(filename, cwd)
  if is_uri(filename) then
    return filename
  end

  -- handles redundant `./` in the middle
  local redundant = path.sep .. "%." .. path.sep
  if filename:match(redundant) then
    filename = filename:gsub(redundant, path.sep)
  end

  local out_file = filename

  local has = string.find(filename, path.sep .. "..", 1, true) or string.find(filename, ".." .. path.sep, 1, true)

  if has then
    local is_abs = is_absolute(filename, path.sep)
    local split_without_disk_name = function(filename_local)
      local parts = _split_by_separator(filename_local)
      -- Remove disk name part on Windows
      if path.sep == "\\" and is_abs then
        table.remove(parts, 1)
      end
      return parts
    end

    local parts = split_without_disk_name(filename)
    local idx = 1
    local initial_up_count = 0

    repeat
      if parts[idx] == ".." then
        if idx == 1 then
          initial_up_count = initial_up_count + 1
        end
        table.remove(parts, idx)
        table.remove(parts, idx - 1)
        if idx > 1 then
          idx = idx - 2
        else
          idx = idx - 1
        end
      end
      idx = idx + 1
    until idx > #parts

    local prefix = ""
    if is_abs or #split_without_disk_name(cwd) == initial_up_count then
      prefix = path.root(filename)
    end

    out_file = prefix .. table.concat(parts, path.sep)
  end

  return out_file
end

local clean = function(pathname)
  if is_uri(pathname) then
    return pathname
  end

  -- Remove double path seps, it's annoying
  pathname = pathname:gsub(path.sep .. path.sep, path.sep)

  -- Remove trailing path sep if not root
  if not is_root(pathname) and pathname:sub(-1) == path.sep then
    return pathname:sub(1, -2)
  end
  return pathname
end

-- S_IFCHR  = 0o020000  # character device
-- S_IFBLK  = 0o060000  # block device
-- S_IFIFO  = 0o010000  # fifo (named pipe)
-- S_IFLNK  = 0o120000  # symbolic link
-- S_IFSOCK = 0o140000  # socket file

---@class Path
local Path = {
  path = path,
}

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
  return clean(self.filename)
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

  -- TODO: Should probably remove and dumb stuff like double seps, periods in the middle, etc.
  local sep = path.sep
  if type(path_input) == "table" then
    sep = path_input.sep or path.sep
    path_input.sep = nil
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

    path_string = table.concat(path_objs, sep)
  else
    assert(type(path_input) == "string", vim.inspect(path_input))
    path_string = path_input
  end

  local obj = {
    filename = path_string,

    _sep = sep,
  }

  setmetatable(obj, Path)

  return obj
end

function Path:_fs_filename()
  return self:absolute() or self.filename
end

function Path:_stat()
  return uv.fs_stat(self:_fs_filename()) or {}
  -- local stat = uv.fs_stat(self:absolute())
  -- if not self._absolute then return {} end

  -- if not self._stat_result then
  --   self._stat_result =
  -- end

  -- return self._stat_result
end

function Path:absolute()
  if self:is_absolute() then
    return _normalize_path(self.filename, self._cwd)
  else
    return _normalize_path(self._absolute or table.concat({ self._cwd, self.filename }, self._sep), self._cwd)
  end
end

function Path:exists()
  return not vim.tbl_isempty(self:_stat())
end

function Path:make_relative(cwd)
  if is_uri(self.filename) then
    return self.filename
  end

  self.filename = clean(self.filename)
  cwd = clean(F.if_nil(cwd, self._cwd, cwd))
  if self.filename == cwd then
    self.filename = "."
  else
    if cwd:sub(#cwd, #cwd) ~= path.sep then
      cwd = cwd .. path.sep
    end

    if self.filename:sub(1, #cwd) == cwd then
      self.filename = self.filename:sub(#cwd + 1, -1)
    end
  end

  return self.filename
end

function Path:normalize(cwd)
  if is_uri(self.filename) then
    return self.filename
  end

  self:make_relative(cwd)

  -- Substitute home directory w/ "~"
  -- string.gsub is not useful here because usernames with dashes at the end
  -- will be seen as a regexp pattern rather than a raw string
  local home = path.home
  if string.sub(path.home, -1) ~= path.sep then
    home = home .. path.sep
  end
  local start, finish = string.find(self.filename, home, 1, true)
  if start == 1 then
    self.filename = "~" .. path.sep .. string.sub(self.filename, (finish + 1), -1)
  end

  return _normalize_path(clean(self.filename), self._cwd)
end

local function shorten_len(filename, len, exclude)
  len = len or 1
  exclude = exclude or { -1 }
  local exc = {}

  -- get parts in a table
  local parts = {}
  local empty_pos = {}
  for m in (filename .. path.sep):gmatch("(.-)" .. path.sep) do
    if m ~= "" then
      parts[#parts + 1] = m
    else
      table.insert(empty_pos, #parts + 1)
    end
  end

  for _, v in pairs(exclude) do
    if v < 0 then
      exc[v + #parts + 1] = true
    else
      exc[v] = true
    end
  end

  local final_path_components = {}
  local count = 1
  for _, match in ipairs(parts) do
    if not exc[count] and #match > len then
      table.insert(final_path_components, string.sub(match, 1, len))
    else
      table.insert(final_path_components, match)
    end
    table.insert(final_path_components, path.sep)
    count = count + 1
  end

  local l = #final_path_components -- so that we don't need to keep calculating length
  table.remove(final_path_components, l) -- remove final slash

  -- add back empty positions
  for i = #empty_pos, 1, -1 do
    table.insert(final_path_components, empty_pos[i], path.sep)
  end

  return table.concat(final_path_components)
end

function Path:shorten(len, exclude)
  assert(len ~= 0, "len must be at least 1")
  if (len and len > 1) or exclude ~= nil then
    return shorten_len(self.filename, len, exclude)
  end
  return shorten_len(self.filename, 1)
end

function Path:is_absolute()
  return is_absolute(self.filename, self._sep)
end
-- }}}

function Path:_split()
  return vim.split(self:absolute(), self._sep)
end

local _get_parent = (function()
  local formatted = string.format("^(.+)%s[^%s]+", path.sep, path.sep)
  return function(abs_path)
    local parent = abs_path:match(formatted)
    if parent ~= nil and not parent:find(path.sep) then
      return parent .. path.sep
    end
    return parent
  end
end)()

function Path:parent()
  return Path:new(_get_parent(self:absolute()) or path.root(self:absolute()))
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

local band = function(reg, value)
  return bit.band(reg, value) == reg
end
local concat_paths = function(...)
  return table.concat({ ... }, path.sep)
end

function Path:mkdir(opts)
  opts = opts or {}

  local mode = opts.mode or 448 -- 0700 -> decimal
  local parents = F.if_nil(opts.parents, false, opts.parents)
  local exists_ok = F.if_nil(opts.exists_ok, true, opts.exists_ok)

  local exists = self:exists()
  if not exists_ok and exists then
    error("FileExistsError:" .. self:absolute())
  end

  -- fs_mkdir returns nil if folder exists
  if not uv.fs_mkdir(self:_fs_filename(), mode) and not exists then
    if parents then
      local dirs = self:_split()
      local processed = ""
      for _, dir in ipairs(dirs) do
        if dir ~= "" then
          local joined = concat_paths(processed, dir)
          if processed == "" and self._sep == "\\" then
            joined = dir
          end
          local stat = uv.fs_stat(joined) or {}
          local file_mode = stat.mode or 0
          if band(S_IF.REG, file_mode) then
            error(string.format("%s is a regular file so we can't mkdir it", joined))
          elseif band(S_IF.DIR, file_mode) then
            processed = joined
          else
            if uv.fs_mkdir(joined, mode) then
              processed = joined
            else
              error("We couldn't mkdir: " .. joined)
            end
          end
        end
      end
    else
      error "FileNotFoundError"
    end
  end

  return true
end

function Path:touch(opts)
  opts = opts or {}

  local mode = opts.mode or 420
  local parents = F.if_nil(opts.parents, false, opts.parents)

  if self:exists() then
    local new_time = os.time()
    uv.fs_utime(self:_fs_filename(), new_time, new_time)
    return
  end

  if parents then
    Path:new(self:parent()):mkdir { parents = true }
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

function Path:head(lines)
  lines = lines or 10
  self = check_self(self)
  local chunk_size = 256

  local fd = uv.fs_open(self:_fs_filename(), "r", 438)
  if not fd then
    return
  end
  local stat = assert(uv.fs_fstat(fd))
  if stat.type ~= "file" then
    uv.fs_close(fd)
    return nil
  end

  local data = ""
  local index, count = 0, 0
  while count < lines and index < stat.size do
    local read_chunk = assert(uv.fs_read(fd, chunk_size, index))

    local i = 0
    for char in read_chunk:gmatch "." do
      if char == "\n" then
        count = count + 1
        if count >= lines then
          break
        end
      end
      index = index + 1
      i = i + 1
    end
    data = data .. read_chunk:sub(1, i)
  end
  assert(uv.fs_close(fd))

  -- Remove potential newline at end of file
  if data:sub(-1) == "\n" then
    data = data:sub(1, -2)
  end

  return data
end

function Path:readlines()
  self = check_self(self)

  local data = self:read()

  data = data:gsub("\r", "")
  return vim.split(data, "\n")
end

function Path:iter()
  local data = self:readlines()
  local i = 0
  local n = #data
  return function()
    i = i + 1
    if i <= n then
      return data[i]
    end
  end
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
