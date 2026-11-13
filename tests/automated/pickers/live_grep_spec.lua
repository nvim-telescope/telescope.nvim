local t = require("test.harness")
local assert = require("test.assert")
local describe, it, after_each = t.describe, t.it, t.after_each

if require("telescope.utils").iswin then
  return
end

local h = require("tests.helpers")
local eq = assert.eq

describe("builtin.live_grep", function()
  after_each(h.cleanup)

  for _, sorting_strategy in ipairs({ "descending", "ascending" }) do
    it("clears results correctly, sorting " .. sorting_strategy, function()
      local picker = h.picker("live_grep", {
        sorter = require("telescope.sorters").get_fzy_sorter(),
        sorting_strategy = sorting_strategy,
        layout_strategy = "center",
        cwd = "./tests/fixtures/live_grep",
        temp__scrolling_limit = 5,
      })
      h.type(picker, "abcd")
      eq(5, #h.results(picker))
    end)
  end
end)
