
local scroller = {}

scroller.create = function(strategy)
  if strategy == 'cycle' then
    return function(max_results, num_results, row)
      local count = math.min(max_results, num_results)

      if row >= count then
        return 0
      elseif row < 0 then
        return count - 1
      end

      return row
    end
  elseif strategy == 'limit' or strategy == nil then
    return function(max_results, num_results, row)
      local count = math.min(max_results, num_results)

      if row >= count then
        return count - 1
      elseif row < 0 then
        return 0
      end

      return row
    end
  else
    error("Unsupported strategy: ", strategy)
  end
end

return scroller
