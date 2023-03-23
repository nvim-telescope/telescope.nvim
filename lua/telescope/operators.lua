local operators = {}

local last_operator = {}

operators.operator_callback = function()
  last_operator.callback(last_operator.opts)
end

-- enter operator-pending mode, see `:h map-operator`
-- params:
--   callback: the callback function to call after exiting operator-pending
--   opts: options to pass to the callback
operators.run_operator = function(callback, opts)
  last_operator = { callback = callback, opts = opts }
  vim.o.operatorfunc = "v:lua.require'telescope.operators'.operator_callback"
  vim.api.nvim_feedkeys("g@", "mi", false)
end

return operators
