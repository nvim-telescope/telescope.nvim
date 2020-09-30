
local t = setmetatable({}, {
  __newindex = function(t, k, v)
    print(t, k, v)
  end
})

-- table.insert(t, "hello")
t[1] = "hello"
