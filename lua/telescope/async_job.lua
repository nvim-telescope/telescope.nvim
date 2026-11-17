local uv = vim.uv

local async = require "neoplen.async"
local channel = async.control.channel
local log = require "telescope.log"
local utils = require "telescope.utils"

local M = {}

local AsyncJob = {}
AsyncJob.__index = AsyncJob

function AsyncJob.new(opts)
  local self = setmetatable({}, AsyncJob)

  self.command, self.uv_opts = M.convert_opts(opts)

  self.stdin = opts.stdin or M.NullPipe()
  self.stdout = opts.stdout or M.NullPipe()
  self.stderr = opts.stderr or M.NullPipe()

  if opts.cwd and opts.cwd ~= "" then
    self.uv_opts.cwd = utils.path_expand(opts.cwd)
  end

  self.uv_opts.stdio = {
    self.stdin.handle,
    self.stdout.handle,
    self.stderr.handle,
  }

  return self
end

function AsyncJob:close(force)
  if force == nil then
    force = true
  end

  for _, pipe in ipairs { self.stdin, self.stdout, self.stderr } do
    pipe:close(force)
  end

  uv.process_kill(self.handle, "sigterm")

  log.debug "[async_job] closed"
end

M.spawn = function(opts)
  local self = AsyncJob.new(opts)
  self.handle, self.pid = uv.spawn(
    self.command,
    self.uv_opts,
    async.void(function()
      self:close(false)
      if not self.handle:is_closing() then
        self.handle:close()
      end
    end)
  )

  if not self.handle then
    error(debug.traceback("Failed to spawn process: " .. vim.inspect(self)))
  end

  return self
end

---@class telescope.async_job.Pipe
---@field handle uv.uv_pipe_t? libuv pipe (nil for `NullPipe`)
---@field eof_tx fun() signals end of file
---@field eof_rx async fun() waits for end of file
local Pipe = {}
Pipe.__index = Pipe

---@param handle uv.uv_pipe_t?
---@return telescope.async_job.Pipe
local function new_pipe(handle)
  local self = setmetatable({ handle = handle }, Pipe)
  -- must be per instance: a oneshot channel can only be used once
  self.eof_tx, self.eof_rx = channel.oneshot()
  return self
end

--- Pipe for reading process output line by line (see `Pipe:iter()`)
---@return telescope.async_job.Pipe
function M.LinesPipe()
  return new_pipe(uv.new_pipe(false))
end

--- Placeholder for an unused stdio stream: no handle, already at end of file
---@return telescope.async_job.Pipe
function M.NullPipe()
  local self = new_pipe(nil)
  self.eof_tx()
  return self
end

---@param force boolean? if false, wait for end of file first (default: true)
function Pipe:close(force)
  if force == nil then
    force = true
  end

  -- `NullPipe` has nothing to close
  if not self.handle or self.handle:is_closing() then
    return
  end

  -- If we're not forcing the stop, allow waiting for eof
  -- This ensures that we don't end up with weird race conditions
  if not force then
    self.eof_rx()
  end

  self.handle:read_stop()
  if not self.handle:is_closing() then
    self.handle:close()
  end
end

function Pipe:read()
  local read_tx, read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    assert(not err, err)
    self.handle:read_stop()

    read_tx(data)
    if data == nil then
      self.eof_tx()
    end
  end)

  return read_rx()
end

--- Iterate over the lines of the output, without line endings and `\r` (split at `opts.split_char`,
--- one character, default "\n"). Yields to the main loop once per chunk read: `read()` resumes from
--- the libuv read callback (a fast event), and the consumer may use the API.
---@param opts? { split_char: string? }
---@return fun(): string?
function Pipe:iter(opts)
  local split_char = opts and opts.split_char or "\n"
  local text, pos, eof = "", 1, false

  -- no loop: a loop here, inside the consumer's loop over the lines, keeps LuaJIT from compiling
  -- the consumer's loop well; the next chunk is read with a tail call instead
  local function next_line()
    local found = string.find(text, split_char, pos, true)
    if found then
      local line = string.sub(text, pos, found - 1)
      pos = found + 1 -- `split_char` is one character
      return line
    end
    if eof then
      if pos > #text then
        return nil
      end
      -- the last line has no line ending
      local line = string.sub(text, pos)
      pos = #text + 1
      return line
    end

    local chunk = self:read()
    async.util.scheduler()
    if chunk == nil then
      eof = true
    else
      -- `gsub` tries the pattern at every byte; most tools print no `\r` at all
      if string.find(chunk, "\r", 1, true) then
        chunk = string.gsub(chunk, "\r", "")
      end
      text, pos = string.sub(text, pos) .. chunk, 1
    end
    return next_line()
  end

  return next_line
end

M.convert_opts = function(o)
  if not o then
    error(debug.traceback "Options are required for Job:new")
  end

  local command = o.command
  if not command then
    if o[1] then
      command = o[1]
    else
      error(debug.traceback "'command' is required for Job:new")
    end
  elseif o[1] then
    error(debug.traceback "Cannot pass both 'command' and array args")
  end

  local args = o.args
  if not args then
    if #o > 1 then
      args = { select(2, unpack(o)) }
    end
  end

  local ok, is_exe = pcall(vim.fn.executable, command)
  if not o.skip_validation and ok and 1 ~= is_exe then
    error(debug.traceback(command .. ": Executable not found"))
  end

  local obj = {}

  obj.args = args

  if o.env then
    if type(o.env) ~= "table" then
      error(debug.traceback "'env' has to be a table")
    end

    local transform = {}
    for k, v in pairs(o.env) do
      if type(k) == "number" then
        table.insert(transform, v)
      elseif type(k) == "string" then
        table.insert(transform, k .. "=" .. tostring(v))
      end
    end
    obj.env = transform
  end

  return command, obj
end

return M
