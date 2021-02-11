local co = coroutine
local uv = vim.loop

local LinkedList = require('telescope.algos.linked_list')

local modes = setmetatable({
  init = "init",
  next = "next",
  done = "done",
}, { __index = function(_, k)
  error(string.format("'%s' is not a valid mode", k))
end })

local is_dead = function(c)
  return co.status(c) == "dead"
end

local Executor = {}
Executor.__index = Executor

-- TODO: I would like to make it so we just have one function for each task,
-- but I think it's fine for now to store both things.
function Executor:new(func)
  return setmetatable({
    func = func,

    -- mode = modes.init,
    -- tasks = LinkedList:new(),

    -- Will be initialized at each run.
    _idle = nil,
  }, self)
end

function Executor:run()
  if not self._idle then
    self._idle = uv.new_idle()
    -- self._idle = uv.new_check()
  end

  self._idle:start((function()
    -- if self.tasks.size == 0 then
    --   return self:stop()
    -- end
    self:step()

    if true then return end

    if self.mode == modes.init then
      self:start()
    end

    if self.mode == modes.next then
      self:step()
    elseif self.mode == modes.done then
      self:complete()
    else
      error(debug.traceback("Unknown mode: " .. tostring(self.mode)))
    end
  end))
end

function Executor:start()
  self.mode = modes.next
end

function Executor:step()
  co.resume(self.func)
  if is_dead(self.func) then
    print("DEAD")
    -- self.tasks:shift()
    return self:stop()
  else
    return self
  end

  if self.tasks.size == 0 then return end

  local task = self.tasks.head.item
  if task == nil then
    error("Should not get step with no tasks left")
  end

  local task_co = task[1]
  co.resume(task_co, unpack(task[2]))
  if is_dead(task_co) then
    print("DEAD")
    self.tasks:shift()
  end
end

function Executor:complete()
end

function Executor:stop()
  if not self._idle then return end

  self._idle:stop()
  self._idle:close()
  self._idle = nil

  return self
end

return Executor
