local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each = t.describe, t.it, t.after_each
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("picker actions", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("cycle previewers of a picker without previewers", function()
    exec_lua(function()
      local assert = require("test.assert")
      require("telescope.pickers")
        .new({}, { finder = require("telescope.finders").new_table({ results = { "a" } }) })
        :find()
      local ok, err = pcall(require("telescope.actions").cycle_previewers_next, vim.api.nvim_get_current_buf())
      assert(ok, err)
    end)
  end)
end)
