local uv = require('luv')

-- print(vim.inspect(uv))


local my_table = {}
local my_value = 1

local table_adder = uv.new_thread(function(tbl)
  table.insert(tbl, "HELLO")
end, my_table)

uv.thread_join(table_adder)
-- print(vim.inspect(MY_TABLE))

