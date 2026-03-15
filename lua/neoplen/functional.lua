local f = {}

function f.any(fun, iterable)
  for k, v in pairs(iterable) do
    if fun(k, v) then
      return true
    end
  end

  return false
end

local function select_only(n)
  return function(...)
    local x = select(n, ...)
    return x
  end
end

f.first = select_only(1)
f.second = select_only(2)
f.third = select_only(3)

return f
