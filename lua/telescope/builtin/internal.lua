local m = setmetatable({}, {
  __index = function(_, k)
    local utils = require "telescope.utils"
    utils.notify("builtin", {
      msg = string.format(
        'You are using an internal interface. Do not use `require("telescope.builtin.internal").%s`,'
          .. ' please use `require("telescope.builtin").%s`! We will remove this endpoint soon!',
        k,
        k
      ),
      level = "ERROR",
    })
    return require("telescope.builtin")[k]
  end,
})

return m
