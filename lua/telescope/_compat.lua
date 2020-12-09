vim.deepcopy = (function()
  local function _id(v)
    return v
  end

  local deepcopy_funcs = {
    table = function(orig)
      local copy = {}

      if vim._empty_dict_mt ~= nil and getmetatable(orig) == vim._empty_dict_mt then
        copy = vim.empty_dict()
      end

      for k, v in pairs(orig) do
        copy[vim.deepcopy(k)] = vim.deepcopy(v)
      end

      if getmetatable(orig) then
        setmetatable(copy, getmetatable(orig))
      end

      return copy
    end,
    ['function'] = _id or function(orig)
      local ok, dumped = pcall(string.dump, orig)
      if not ok then
        error(debug.traceback(dumped))
      end

      local cloned = loadstring(dumped)
      local i = 1
      while true do
        local name = debug.getupvalue(orig, i)
        if not name then
          break
        end
        debug.upvaluejoin(cloned, i, orig, i)
        i = i + 1
      end
      return cloned
    end,
    number = _id,
    string = _id,
    ['nil'] = _id,
    boolean = _id,
  }

  return function(orig)
    local f = deepcopy_funcs[type(orig)]
    if f then
      return f(orig)
    else
      error("Cannot deepcopy object of type "..type(orig))
    end
  end
end)()
