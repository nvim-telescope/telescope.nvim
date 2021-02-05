local uv = vim.loop

local modes = setmetatable({
  init = "init",
  next = "next",
  done = "done",
}, { __index = function(_, k)
  error(string.format("'%s' is not a valid mode", k))
end })

local Executor = {}
Executor.__index = Executor

function Executor:new()
  return setmetatable({
    tasks = {},
    mode = modes.next,
    index = 1,
    _idle = nil,
  }, self)
end

function Executor:run()
  if not self._idle then
    self._idle = uv.new_idle()
  end

  self._idle:start(function()
    if #self.tasks == 0 then
      return self:stop()
    end

    if self.mode == modes.init 
        or self.mode == modes.next then
      self:step()
    elseif self.mode == modes.done then
      self:complete()
    else
      error(debug.traceback("Unknown mode: " .. tostring(self.mode)))
    end
  end)
end

function Executor:complete()
end

function Executor:step()
  if #self.tasks == 0 then return end
end

function Executor:stop()
  self._idle:stop()
  self._idle:close()
  self._idle = nil

  return self
end
