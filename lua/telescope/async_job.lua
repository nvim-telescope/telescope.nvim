local uv = vim.uv

local log = require "neoplen.log"

local async = require "neoplen.async"
local channel = require("neoplen.async").control.channel
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
    -- this is a "illegal" hack for windows. E.g. If the git command returns `/` rather than `\` as delimiter,
    -- vim.fn.expand might just end up returning an empty string. Weird
    -- Because empty string is not allowed in libuv the job will not spawn. Solution is we just set it to opts.cwd
    if self.uv_opts.cwd == "" then
      self.uv_opts.cwd = opts.cwd
    end
  end

  self.uv_opts.stdio = {
    self.stdin.handle,
    self.stdout.handle,
    self.stderr.handle,
  }

  return self
end

function AsyncJob:_for_each_pipe(f, ...)
  for _, pipe in ipairs { self.stdin, self.stdout, self.stderr } do
    f(pipe, ...)
  end
end

function AsyncJob:close(force)
  if force == nil then
    force = true
  end

  self:_for_each_pipe(function(p)
    p:close(force)
  end)

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

  self._closed = true
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

function Pipe:iter(schedule, opts)
  schedule = utils.if_nil(schedule, true)
  local split_char = utils.if_nil(opts and opts.split_char, "\n")

  local text = nil
  local index = nil

  local get_next_text = function(previous)
    index = nil

    local read = self:read()
    if previous == nil and read == nil then
      return
    end

    read = string.gsub(read or "", "\r", "")
    return (previous or "") .. read
  end

  local function next_value()
    if schedule then
      async.util.scheduler()
    end

    if text == nil or (text == "" and index == nil) then
      return nil
    end

    local start = index
    index = string.find(text, split_char, index, true)

    if index == nil then
      text = get_next_text(string.sub(text, start or 1))
      return next_value()
    end

    index = index + 1

    return string.sub(text, start or 1, index - 2)
  end

  text = get_next_text()

  return function()
    return next_value()
  end
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
