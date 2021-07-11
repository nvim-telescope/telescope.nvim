local path = setmetatable({}, {
  __index = function()
    error("telescope.path is deprecated. please use plenary.path instead")
  end
})

return path
