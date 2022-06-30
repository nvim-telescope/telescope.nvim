local tester = require "telescope.testharness"

--[[
Available functions are
- fixtures/file_a.txt
- fixtures/file_abc.txt
--]]

describe("scroll_cycle", function()
  it("should be able to cycle selections: cycle", function()
    tester.run_string [[
      runner.picker("find_files", "fixtures/file<c-p>", {
        post_close = {
          { "lua/tests/fixtures/file_abc.txt", helper.get_selection_value },
        },
      }, {
        sorting_strategy = "ascending",
        scroll_strategy = "cycle",
      })
    ]]
  end)

  for _, sorting in ipairs { "ascending", "descending" } do
    for _, key in ipairs { "<c-n>", "<c-p>" } do
      it(string.format("Cycle: %sx2 %s", key, sorting), function()
        tester.run_string(([[
          runner.picker("find_files", "fixtures/file%s%s", {
              post_typed = {
                { "lua/tests/fixtures/file_a.txt", helper.get_selection_value },
              },
            }, {
              sorting_strategy = "%s",
              scroll_strategy = "cycle",
            }
          ) ]]):format(key, key, sorting))
      end)

      it(string.format("Cycle: %sx3 %s", key, sorting), function()
        tester.run_string(([[
          runner.picker("find_files", "fixtures/file%s%s%s", {
              post_typed = {
                { "lua/tests/fixtures/file_abc.txt", helper.get_selection_value },
              },
            }, {
              sorting_strategy = "%s",
              scroll_strategy = "cycle",
            }
          ) ]]):format(key, key, key, sorting))
      end)
    end
  end

  it("should be able to cycle selections: limit", function()
    tester.run_string [[
      runner.picker("find_files", "fixtures/file<c-p>", {
        post_close = {
          { "lua/tests/fixtures/file_a.txt", helper.get_selection_value },
        },
      }, {
        sorting_strategy = "ascending",
        scroll_strategy = "limit",
      })
    ]]
  end)

  it("long: cycle to top", function()
    tester.run_string [[
      runner.picker("find_files", "fixtures/long<c-p>", {
        post_close = {
          { "lua/tests/fixtures/long_11111111111.md", helper.get_selection_value },
        },
      }, {
        sorting_strategy = "ascending",
        scroll_strategy = "cycle",
        height = 10,
      })
    ]]
  end)

  it("long: cycle to top", function()
    tester.run_string [[
      runner.picker("find_files", "fixtures/long<c-n>", {
        post_close = {
          { "lua/tests/fixtures/long_11111111111.md", helper.get_selection_value },
        },
      }, {
        sorting_strategy = "descending",
        scroll_strategy = "cycle",
        height = 10,
      })
    ]]
  end)

  it("long: smash <c-p>", function()
    tester.run_string [[
      runner.picker("find_files", "fixtures/long<c-p><c-p><c-p><c-p><c-p>", {
        post_typed = {
          { "lua/tests/fixtures/long_111111.md", helper.get_selection_value },
        },
      }, {
        sorting_strategy = "descending",
        scroll_strategy = "cycle",
        layout_config = {
          height = 8,
        },
      })
    ]]
  end)
end)
