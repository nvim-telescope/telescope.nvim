
local action_mt = {}   

action_mt.create = function(mod)
  local mt = {
    __call = function(t, ...)
      local values = {}
      for _, v in ipairs(t) do
        local func = t._replacements[v] or mod[v]

        if t._pre[v] then
          t._pre[v](...)
        end

        local result = {func(...)}
        for _, res in ipairs(result) do
          table.insert(values, res)
        end

        if t._post[v] then
          t._post[v](...)
        end
      end

      return unpack(values)
    end,

    __add = function(lhs, rhs)
      local new_actions = {}
      for _, v in ipairs(lhs) do
        table.insert(new_actions, v)
      end

      for _, v in ipairs(rhs) do
        table.insert(new_actions, v)
      end

      return setmetatable(new_actions, getmetatable(lhs))
    end,

    _pre = {},
    _replacements = {},
    _post = {},
  }

  mt.__index = mt

  mt.clear = function()
    mt._pre = {}
    mt._replacements = {}
    mt._post = {}
  end

  --- Replace the reference to the function with a new one temporarily
  function mt:replace(v)
    assert(#self == 1, "Cannot replace an already combined action")

    local action_name = self[1]
    mt._replacements[action_name] = v
  end

  function mt:enhance(opts)
    assert(#self == 1, "Cannot enhance already combined actions")

    local action_name = self[1]
    if opts.pre then
      mt._pre[action_name] = opts.pre
    end

    if opts.post then
      mt._post[action_name] = opts.post
    end
  end

  return mt
end

action_mt.transform = function(k, mt)
  return setmetatable({k}, mt)
end

action_mt.transform_mod = function(mod)
  local mt = action_mt.create(mod)

  local redirect = {}

  for k, _ in pairs(mod) do
    redirect[k] = action_mt.transform(k, mt)
  end

  redirect._clear = mt.clear

  return redirect
end

return action_mt
