local uv = vim.uv

local log = require "telescope.log"
local utils = require "telescope.utils"

local M = {}

local AsyncJob = {}
AsyncJob.__index = AsyncJob

--- Stop the process and its output pipe (if the process still runs, it gets SIGTERM).
function AsyncJob:close()
  if self.stdout then
    self.stdout:close()
  end
  if not self.handle:is_closing() then
    uv.process_kill(self.handle, "sigterm")
  end
  log.debug "[async_job] closed"
end

--- Start a process. Its stdin is empty and its stderr discarded; read its output through `stdout`, a
--- `LinesPipe()`, which closes itself at the end of the output.
---@param opts { command: string, args: string[]?, cwd: string?, env: table?, stdout: telescope.async_job.Pipe? }
M.spawn = function(opts)
  local command = assert(opts.command, "`command` is required")
  -- `executable()` can't be called from a libuv callback; let `uv.spawn` fail then
  local ok, is_exe = pcall(vim.fn.executable, command)
  if ok and is_exe ~= 1 then
    error(debug.traceback(command .. ": Executable not found"))
  end
  local env -- `{ "NAME=value", ... }` from `{ NAME = value }` (and "NAME=value" list items)
  if opts.env then
    env = {}
    for k, v in pairs(opts.env) do
      if type(k) == "number" then
        env[#env + 1] = v
      elseif type(k) == "string" then
        env[#env + 1] = k .. "=" .. tostring(v)
      end
    end
  end

  local self = setmetatable({ stdout = opts.stdout }, AsyncJob)
  self.handle, self.pid = uv.spawn(command, {
    args = opts.args,
    cwd = opts.cwd and opts.cwd ~= "" and utils.path_expand(opts.cwd) or nil,
    env = env,
    stdio = { nil, self.stdout and self.stdout.handle, nil },
  }, function()
    self.handle:close()
  end)
  if not self.handle then
    if self.stdout then
      self.stdout:close()
    end
    error(debug.traceback("Failed to spawn process: " .. vim.inspect(opts)))
  end
  return self
end

---@class telescope.async_job.Pipe
---@field handle uv.uv_pipe_t libuv pipe
---@field package reading boolean? a read is pending
---@field package ready boolean? `err` and `data` hold a chunk not yet returned by `read()`
---@field package err string?
---@field package data string?
---@field package wake fun()? resumes the current reader
local Pipe = {}
Pipe.__index = Pipe

--- Pipe for reading process output line by line (see `Pipe:iter()`)
---@return telescope.async_job.Pipe
function M.LinesPipe()
  return setmetatable({ handle = uv.new_pipe(false) }, Pipe)
end

function Pipe:close()
  if not self.handle:is_closing() then
    self.handle:close()
  end
end

--- The next chunk of output, or nil at the end of the output (the pipe is closed then). Waits inside
--- a `vim.async` task and resumes from the main loop, where the API can be used. The chunk is kept in
--- the pipe until it is returned, so a read whose task is closed loses nothing: the next read gets it.
function Pipe:read()
  if not self.ready then
    vim.async.await(1, function(wake)
      self.wake = wake -- the reader of a closed task never wakes: wake the current one
      if self.reading then
        return
      end
      self.reading = true
      self.handle:read_start(function(err, data)
        self.handle:read_stop()
        if err or data == nil then
          self:close()
        end
        vim.schedule(function()
          self.reading, self.ready, self.err, self.data = false, true, err, data
          self.wake()
        end)
      end)
    end)
  end
  self.ready = false
  if self.err then
    error(self.err)
  end
  return self.data
end

--- Iterate over the lines of the output, without line endings and `\r` (split at `opts.split_char`,
--- one character, default "\n"). Yields to the main loop once per chunk read (`read()`), so the
--- consumer may use the API. If the consumer's task is closed while it waits, a later call (from
--- another task) continues where it stopped.
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

return M
