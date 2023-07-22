local operators = {}

local last_operator = { callback = function(_) end, opts = {} }

--- Execute the last saved operator callback and options
operators.operator_callback = function()
  last_operator.callback(last_operator.opts)
end

--- Enters operator-pending mode, then executes callback.
--- See `:h map-operator`
---
---@param callback function: the function to call after exiting operator-pending
---@param opts table: options to pass to the callback
operators.run_operator = function(callback, opts)
  last_operator = { callback = callback, opts = opts }
  vim.o.operatorfunc = "v:lua.require'telescope.operators'.operator_callback"
  -- feed g@ to enter operator-pending mode
  -- 'i' required for which-key compatibility, etc.
  vim.api.nvim_feedkeys("g@", "mi", false)
end

return operators
