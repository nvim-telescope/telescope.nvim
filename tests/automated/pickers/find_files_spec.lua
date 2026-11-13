local t = require("test.harness")
local assert = require("test.assert")
local describe, it, after_each = t.describe, t.it, t.after_each

if require("telescope.utils").iswin then
  return
end

local actions = require("telescope.actions")
local h = require("tests.helpers")
local eq = assert.eq

describe("builtin.find_files", function()
  after_each(h.cleanup)

  for _, sorting_strategy in ipairs({ "descending", "ascending" }) do
    it("finds the readme without devicons, sorting " .. sorting_strategy, function()
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
  end

  it("finds the readme, using lowercase", function()
    local picker = h.picker("find_files")
    h.type(picker, "readme.md")
    eq("README.md", h.select(picker))
  end)

  it("finds pickers.lua", function()
    local picker = h.picker("find_files")
    h.type(picker, "pickers.lua")
    eq("pickers.lua", h.select(picker))
  end)

  it("moves the selection with <C-n>", function()
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

  it("cycles the selection with scroll_strategy = cycle", function()
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

  it("gets the current selection", function()
    local picker = h.picker("find_files")
    h.type(picker, "fixtures/find_files/file_abc")
    eq("tests/fixtures/find_files/file_abc.txt", require("telescope.actions.state").get_selected_entry().value)
  end)
end)
