RELOAD('docgen')

local docgen = require('docgen')

local docs = {}

docs.test = function()
  local input_dir = "./lua/telescope/"
  local input_files = vim.fn.globpath(input_dir, "**/*.lua", false, true)

  -- TODO: Fix the other files so that we can add them here.
  input_files = {
    "./lua/telescope/init.lua"
  }

  table.sort(input_files, function(a, b)
    return #a < #b
  end)

  local output_file = "./docs/telescope.txt"
  local output_file_handle = io.open(output_file, "w")

  for _, input_file in ipairs(input_files) do
    docgen.write(input_file, output_file_handle)
  end

  output_file_handle:write(" vim:tw=78:ts=8:ft=help:norl:")
  output_file_handle:close()
  vim.cmd [[checktime]]
end

docs.test()

return docs
