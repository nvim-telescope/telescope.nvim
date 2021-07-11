local path = {}

path.separator = package.config:sub(1, 1)
path.home = vim.fn.expand("~")

path.make_relative = function()
  error("telescope.path is deprecated. please use plenary.path instead")
end

path.shorten = function()
  error("telescope.path is deprecated. please use plenary.path instead")
end

path.normalize = function()
  error("telescope.path is deprecated. please use plenary.path instead")
end

path.read_file = function()
  error("telescope.path is deprecated. please use plenary.path instead")
end

path.read_file_async = function()
  error("telescope.path is deprecated. please use plenary.path instead")
end

return path
