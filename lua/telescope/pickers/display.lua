local picker_display = {}

picker_display.bind_handle_strategy = function(picker)
  if picker.scroll_strategy == "cycle" then
    return function(self, row)
      if row >= self.max_results then
        return 0
      elseif row < 0 then
        return self.max_results - 1
      end

      return row
    end
  else
    return function(self, row)
      if row >= self.max_results then
        return self.max_results - 1
      elseif row < 0 then
        return 0
      end

      return row
    end
  end
end


picker_display.bind_can_select_row = function(picker)
  if picker.sorting_strategy == 'ascending' then
    return function(self, row)
      return row <= self.manager:num_results()
    end
  else
    return function(self, row)
      return row <= self.max_results
              and row >= self.max_results - self.manager:num_results()
    end
  end
end



picker_display.bind_get_row = function(picker)
  --- Take a row and get an index.
  ---@note: Rows are 0-indexed, and `index` is 1 indexed (table index)
  ---@param index number: The row being displayed
  ---@return number The row for the picker to display in

  if picker.sorting_strategy == 'ascending' then
    return function(_, index) return index - 1 end
  else
    return function(self, index) return self.max_results - index end
  end
end

picker_display.bind_get_index = function(picker)
  --- Take a row and get an index
  ---@note: Rows are 0-indexed, and `index` is 1 indexed (table index)
  ---@param row number: The row being displayed
  ---@return number The index in line_manager
  if picker.sorting_strategy == 'ascending' then
    return function(_, row) return row + 1 end
  else
    return function(self, row) return self.max_results - row end
  end
end

picker_display.bind_get_reset_row = function(picker)
  if picker.sorting_strategy == 'ascending' then
    return function(_) return 0 end
  else
    return function(self) return self.max_results - 1 end
  end
end



return picker_display
