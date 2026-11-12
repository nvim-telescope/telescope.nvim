local uv = vim.uv

local async = require "neoplen.async"
local channel = async.control.channel
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
  local self = setmetatable({ stdout = opts.stdout }, AsyncJob)
  local command, uv_opts = M.convert_opts(opts)
  if opts.cwd and opts.cwd ~= "" then
    uv_opts.cwd = utils.path_expand(opts.cwd)
  end
  uv_opts.stdio = { nil, self.stdout and self.stdout.handle, nil }

  self.handle, self.pid = uv.spawn(command, uv_opts, function()
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

--- The next chunk of output, or nil at the end of the output (the pipe is closed then).
function Pipe:read()
  local read_tx, read_rx = channel.oneshot()

  self.handle:read_start(function(err, data)
    assert(not err, err)
    self.handle:read_stop()
    if data == nil then
      self:close()
    end
    read_tx(data)
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
