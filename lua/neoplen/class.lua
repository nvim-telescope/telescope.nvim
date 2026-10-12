---@brief [[
---classic
---
---Copyright (c) 2014, rxi
---@brief ]]

---@class Object
local Object = {}
Object.__index = Object

---Does nothing.
---You have to implement this yourself for extra functionality when initializing
---@param self Object
function Object:new() end

---Create a new class/object by extending the base Object class.
---The extended object will have a field called `super` that will access the super class.
---@param self Object
---@return Object
function Object:extend()
  local cls = {}
  for k, v in pairs(self) do
    if k:find "__" == 1 then
      cls[k] = v
    end
  end
  cls.__index = cls
  cls.super = self
  setmetatable(cls, self)
  return cls
end

---The default tostring implementation for an object.
---You can override this to provide a different tostring.
---@param self Object
---@return string
function Object:__tostring()
  return "Object"
end

---You can call the class the initialize it without using `Object:new`.
---@param self Object
---@param nil ...
---@return Object
function Object:__call(...)
  local obj = setmetatable({}, self)
  obj:new(...)
  return obj
end

return Object
