local m = setmetatable({}, {
  __index = function(_, k)
    local utils = require "telescope.utils"
    utils.notify("builtin", {
      msg = string.format(
        'You are using an internal interface. Do not use `require("telescope.builtin.git").%s`,'
          .. ' please use `require("telescope.builtin").git_%s`! We will remove this endpoint soon!',
        k,
        k
      ),
      level = "ERROR",
    })
    return require("telescope.builtin")["git_" .. k]
  end,
})

return m
