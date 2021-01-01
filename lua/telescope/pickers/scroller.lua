local scroller = {}

local calc_count_fn = function(sorting_strategy)
  if sorting_strategy == 'ascending' then
    return function(a, b) return math.min(a, b) end
  else
    return function(a, b, row)
      if a == b or not row then
        return math.max(a, b)
      else
        local x = a - b
        if row < x then
          return math.max(a, b) - 1, true
        elseif row == a then
          return x, true
        else
          return math.max(a, b)
        end
      end
    end
  end
end

scroller.create = function(strategy, sorting_strategy)
  local calc_count = calc_count_fn(sorting_strategy)

  if strategy == 'cycle' then
    return function(max_results, num_results, row)
      local count, b = calc_count(max_results, num_results, row)
      if b then return count end

      if row >= count then
        return 0
      elseif row < 0 then
        return count - 1
      end

      return row
    end
  elseif strategy == 'limit' or strategy == nil then
    return function(max_results, num_results, row)
      local count = calc_count(max_results, num_results)

      if row >= count then
        return count - 1
      elseif row < 0 then
        return 0
      end

      return row
    end
  else
    error("Unsupported strategy: " .. strategy)
  end
end

return scroller
