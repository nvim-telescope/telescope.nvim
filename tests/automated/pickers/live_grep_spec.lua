local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each, eq = t.describe, t.it, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("builtin.live_grep", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  for _, sorting_strategy in ipairs({ "descending", "ascending" }) do
    it("clears results correctly, sorting " .. sorting_strategy, function()
      eq(
        5,
        exec_lua(function()
          local h = require("tests.picker_helpers")
          local picker = h.picker("live_grep", {
            sorter = require("telescope.sorters").get_fzy_sorter(),
            sorting_strategy = sorting_strategy,
            layout_strategy = "center",
            cwd = "./tests/fixtures/live_grep",
            temp__scrolling_limit = 5,
          })
          h.type(picker, "abcd")
          return #h.results(picker)
        end)
      )
    end)
  end
end)
