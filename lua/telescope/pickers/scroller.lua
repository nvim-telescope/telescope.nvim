local scroller = {}

local range_calculators = {
  ascending = function(max_results, num_results)
    return 0, math.min(max_results, num_results)
  end,

  descending = function(max_results, num_results)
    return math.max(max_results - num_results, 0), max_results
  end,
}

local scroll_calculators = {
  cycle = function(range_fn)
    return function(max_results, num_results, row)
      local start, finish = range_fn(max_results, num_results)

      if row >= finish then
        return start
      elseif row < start then
        return finish - 1
      end

      return row
    end
  end,

  limit = function(range_fn)
    return function(max_results, num_results, row)
      local start, finish = range_fn(max_results, num_results)

      if row >= finish then
        return finish - 1
      elseif row < start then
        return start
      end

      return row
    end
  end,
}

scroller.create = function(scroll_strategy, sorting_strategy)
  local range_fn = range_calculators[sorting_strategy]
  if not range_fn then
    error(debug.traceback("Unknown sorting strategy: " .. sorting_strategy))
  end

  local scroll_fn = scroll_calculators[scroll_strategy]
  if not scroll_fn then
    error(debug.traceback("Unknown scroll strategy: " .. (scroll_strategy or '')))
  end

  local calculator = scroll_fn(range_fn)
  return function(max_results, num_results, row)
    local result = calculator(max_results, num_results, row)

    if result < 0 then
      error(string.format(
        "Must never return a negative row: { result = %s, args = { %s %s %s } }",
        result, max_results, num_results, row
      ))
    end

    if result >= max_results then
      error(string.format(
        "Must never exceed max results: { result = %s, args = { %s %s %s } }",
        result, max_results, num_results, row
      ))
    end

    return result
  end
end

return scroller
