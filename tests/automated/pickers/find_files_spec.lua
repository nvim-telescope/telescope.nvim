local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each, eq = t.describe, t.it, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("builtin.find_files", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  for _, sorting_strategy in ipairs({ "descending", "ascending" }) do
    it("finds the readme without devicons, sorting " .. sorting_strategy, function()
      exec_lua(function()
        local h = require("tests.picker_helpers")
        local eq = require("test.assert").eq
        local picker = h.picker("find_files", {
          disable_devicons = true,
          sorter = require("telescope.sorters").get_fzy_sorter(),
          sorting_strategy = sorting_strategy,
          layout_strategy = "center",
          layout_config = { height = 6, width = 0.9 },
        })
        h.type(picker, "README.md")
        eq("> README.md", h.prompt(picker))
        eq("> README.md", h.best_result(picker))
        eq("README.md", h.select(picker))
      end)
    end)
  end

  it("finds the readme, using lowercase", function()
    eq(
      "README.md",
      exec_lua(function()
        local h = require("tests.picker_helpers")
        local picker = h.picker("find_files")
        h.type(picker, "readme.md")
        return h.select(picker)
      end)
    )
  end)

  it("finds pickers.lua", function()
    eq(
      "pickers.lua",
      exec_lua(function()
        local h = require("tests.picker_helpers")
        local picker = h.picker("find_files")
        h.type(picker, "pickers.lua")
        return h.select(picker)
      end)
    )
  end)

  it("moves the selection with <C-n>", function()
    exec_lua(function()
      local actions = require("telescope.actions")
      local h = require("tests.picker_helpers")
      local eq = require("test.assert").eq
      local picker = h.picker("find_files", {
        sorter = require("telescope.sorters").get_fzy_sorter(),
        sorting_strategy = "ascending",
        disable_devicons = true,
      })
      h.type(picker, "fixtures/find_files/file")
      actions.move_selection_next(picker.prompt_bufnr)
      eq({
        "  tests/fixtures/find_files/file_a.txt",
        "> tests/fixtures/find_files/file_abc.txt",
      }, h.results(picker))
      eq("file_abc.txt", h.select(picker))
    end)
  end)

  it("cycles the selection with scroll_strategy = cycle", function()
    exec_lua(function()
      local actions = require("telescope.actions")
      local h = require("tests.picker_helpers")
      local eq = require("test.assert").eq
      local picker = h.picker("find_files", {
        sorter = require("telescope.sorters").get_fzy_sorter(),
        sorting_strategy = "descending",
        scroll_strategy = "cycle",
        disable_devicons = true,
      })
      h.type(picker, "fixtures/find_files/file")
      local best = h.best_result(picker)
      actions.move_selection_previous(picker.prompt_bufnr)
      actions.move_selection_previous(picker.prompt_bufnr)
      eq(best, h.best_result(picker))
    end)
  end)

  it("gets the current selection", function()
    eq(
      "tests/fixtures/find_files/file_abc.txt",
      exec_lua(function()
        local h = require("tests.picker_helpers")
        local picker = h.picker("find_files")
        h.type(picker, "fixtures/find_files/file_abc")
        return require("telescope.actions.state").get_selected_entry().value
      end)
    )
  end)
end)
