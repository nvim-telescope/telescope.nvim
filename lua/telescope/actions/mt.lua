local action_mt = {}

--- Checks all replacement combinations to determine which function to run.
--- If no replacement can be found, then it will run the original function
local run_replace_or_original = function(replacements, original_func, ...)
  for _, replacement_map in ipairs(replacements or {}) do
    for condition, replacement in pairs(replacement_map) do
      if condition == true or condition(...) then
        return replacement(...)
      end
    end
  end

  return original_func(...)
end

action_mt.create = function()
  local mt = {
    __call = function(t, ...)
      local values = {}
      for _, action_name in ipairs(t) do
        if t._static_pre[action_name] then
          t._static_pre[action_name](...)
        end
        if t._pre[action_name] then
          t._pre[action_name](...)
        end

        local result = {
          run_replace_or_original(t._replacements[action_name], t._func[action_name], ...),
        }
        for _, res in ipairs(result) do
          table.insert(values, res)
        end

        if t._static_post[action_name] then
          t._static_post[action_name](...)
        end
        if t._post[action_name] then
          t._post[action_name](...)
        end
      end

      return unpack(values)
    end,

    __add = function(lhs, rhs)
      local new_actions = setmetatable({}, action_mt.create())
      for _, v in ipairs(lhs) do
        table.insert(new_actions, v)
        new_actions._func[v] = lhs._func[v]
        new_actions._static_pre[v] = lhs._static_pre[v]
        new_actions._pre[v] = lhs._pre[v]
        new_actions._replacements[v] = lhs._replacements[v]
        new_actions._static_post[v] = lhs._static_post[v]
        new_actions._post[v] = lhs._post[v]
      end

      for _, v in ipairs(rhs) do
        table.insert(new_actions, v)
        new_actions._func[v] = rhs._func[v]
        new_actions._static_pre[v] = rhs._static_pre[v]
        new_actions._pre[v] = rhs._pre[v]
        new_actions._replacements[v] = rhs._replacements[v]
        new_actions._static_post[v] = rhs._static_post[v]
        new_actions._post[v] = rhs._post[v]
      end

      return new_actions
    end,

    _func = {},
    _static_pre = {},
    _pre = {},
    _replacements = {},
    _static_post = {},
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

    return self:replace_map { [true] = v }
  end

  function mt:replace_if(condition, replacement)
    assert(#self == 1, "Cannot replace an already combined action")

    return self:replace_map { [condition] = replacement }
  end

  --- Replace table with
  -- Example:
  --
  -- actions.select:replace_map {
  --   [function() return filetype == 'lua' end] = actions.file_split,
  --   [function() return filetype == 'other' end] = actions.file_split_edit,
  -- }
  function mt:replace_map(tbl)
    assert(#self == 1, "Cannot replace an already combined action")

    local action_name = self[1]

    if not mt._replacements[action_name] then
      mt._replacements[action_name] = {}
    end

    table.insert(mt._replacements[action_name], 1, tbl)
    return self
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

    return self
  end

  return mt
end

action_mt.transform = function(k, mt, v)
  local res = setmetatable({ k }, mt)
  if type(v) == "table" then
    res._static_pre[k] = v.pre
    res._static_post[k] = v.post
    res._func[k] = v.action
  else
    res._func[k] = v
  end
  return res
end

action_mt.transform_mod = function(mod)
  -- Pass the metatable of the module if applicable.
  --    This allows for custom errors, lookups, etc.
  local redirect = setmetatable({}, getmetatable(mod) or {})

  for k, v in pairs(mod) do
    local mt = action_mt.create()
    redirect[k] = action_mt.transform(k, mt, v)
  end

  redirect._clear = function()
    for k, v in pairs(redirect) do
      if k ~= "_clear" then
        pcall(v.clear)
      end
    end
  end

  return redirect
end

return action_mt
