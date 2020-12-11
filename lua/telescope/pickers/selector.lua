-- WHY CANT THIS BE SPELLED SELECTER??? :'(

--[[
if selection_strategy == 'row' then
  if self._selection_row == nil and self.default_selection_index ~= nil then
    self:set_selection(self:get_row(self.default_selection_index))
  else
    self:set_selection(self:get_selection_row())
  end
elseif selection_strategy == 'follow' then
  if self._selection_row == nil and self.default_selection_index ~= nil then
    self:set_selection(self:get_row(self.default_selection_index))
  else
    local index = self.manager:find_entry(self:get_selection())

    if index then
      local follow_row = self:get_row(index)
      self:set_selection(follow_row)
    else
      self:set_selection(self:get_reset_row())
    end
  end
elseif selection_strategy == 'reset' then
  if self.default_selection_index ~= nil then
    self:set_selection(self:get_row(self.default_selection_index))
  else
    self:set_selection(self:get_reset_row())
  end
else
  error('Unknown selection strategy: ' .. selection_strategy)
end
--]]


local selector = {}

local row_selector = function(opts)
  local selected = opts.selected
  local default = opts.default

  if selected then
    return selected
  else
    return default
  end
end

local reset_selector = function(opts)
  local default = opts.default
  if default then
    return default
  else
    return opts.reset
  end
end

selector.create = function(strategy)
  if strategy == 'row' then
    return row_selector
  elseif strategy == 'reset' then
    return reset_selector
  else
    error('Unknown selection strategy: ' .. strategy)
  end
end

return selector
