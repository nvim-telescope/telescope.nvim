-- module will return a stub module table
local assert = require "luassert.assert"
local spy = require "luassert.spy"
local util = require "luassert.util"
local unpack = util.unpack
local pack = util.pack

local stub = {}

function stub.new(object, key, ...)
  if object == nil and key == nil then
    -- called without arguments, create a 'blank' stub
    object = {}
    key = ""
  end
  local return_values = pack(...)
  assert(
    type(object) == "table" and key ~= nil,
    "stub.new(): Can only create stub on a table key, call with 2 params; table, key",
    util.errorlevel()
  )
  assert(
    object[key] == nil or util.callable(object[key]),
    "stub.new(): The element for which to create a stub must either be callable, or be nil",
    util.errorlevel()
  )
  local old_elem = object[key] -- keep existing element (might be nil!)

  local fn = (return_values.n == 1 and util.callable(return_values[1]) and return_values[1])
  local defaultfunc = fn or function()
    return unpack(return_values)
  end
  local oncalls = {}
  local callbacks = {}
  local stubfunc = function(...)
    local args = util.make_arglist(...)
    local match = util.matchoncalls(oncalls, args)
    if match then
      return callbacks[match](...)
    end
    return defaultfunc(...)
  end

  object[key] = stubfunc -- set the stubfunction
  local s = spy.on(object, key) -- create a spy on top of the stub function
  local spy_revert = s.revert -- keep created revert function

  s.revert = function(self) -- wrap revert function to restore original element
    if not self.reverted then
      spy_revert(self)
      object[key] = old_elem
      self.reverted = true
    end
    return old_elem
  end

  s.returns = function(...)
    local return_args = pack(...)
    defaultfunc = function()
      return unpack(return_args)
    end
    return s
  end

  s.invokes = function(func)
    defaultfunc = function(...)
      return func(...)
    end
    return s
  end

  s.by_default = {
    returns = s.returns,
    invokes = s.invokes,
  }

  s.on_call_with = function(...)
    local match_args = util.make_arglist(...)
    match_args = util.copyargs(match_args)
    return {
      returns = function(...)
        local return_args = pack(...)
        table.insert(oncalls, match_args)
        callbacks[match_args] = function()
          return unpack(return_args)
        end
        return s
      end,
      invokes = function(func)
        table.insert(oncalls, match_args)
        callbacks[match_args] = function(...)
          return func(...)
        end
        return s
      end,
    }
  end

  return s
end

local function set_stub(state, arguments)
  state.payload = arguments[1]
  state.failure_message = arguments[2]
end

assert:register("modifier", "stub", set_stub)

return setmetatable(stub, {
  __call = function(self, ...)
    -- stub originally was a function only. Now that it is a module table
    -- the __call method is required for backward compatibility
    return stub.new(...)
  end,
})
