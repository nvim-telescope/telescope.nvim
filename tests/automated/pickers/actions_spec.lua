local t = require("test.harness")
local assert = require("test.assert")
local describe, it, after_each = t.describe, t.it, t.after_each

local h = require("tests.helpers")

describe("picker actions", function()
  after_each(h.cleanup)

  it("cycle previewers of a picker without previewers", function()
    require("telescope.pickers")
      .new({}, { finder = require("telescope.finders").new_table({ results = { "a" } }) })
      :find()
    local ok, err = pcall(require("telescope.actions").cycle_previewers_next, vim.api.nvim_get_current_buf())
    assert(ok, err)
  end)
end)
