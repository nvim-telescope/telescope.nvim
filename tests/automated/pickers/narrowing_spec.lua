local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each = t.describe, t.it, t.after_each
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("pickers narrowing", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("doesn't bring back entries deleted from the finder", function()
    exec_lua(function()
      local h = require("tests.picker_helpers")
      local eq = require("test.assert").eq
      require("telescope.pickers")
        .new({}, {
          finder = require("telescope.finders").new_table({ results = { "ab", "ac", "bc" } }),
          sorter = require("telescope.sorters").get_fzy_sorter(),
        })
        :find()
      local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
      picker.__completed = 0
      picker:register_completion_callback(function(p)
        p.__completed = p.__completed + 1
      end)
      h.type(picker, "a")
      eq(2, picker.manager:num_results())

      -- same prompt and finder, but its results changed
      local completed = picker.__completed
      picker:delete_selection(function()
        return true
      end)
      vim.wait(5000, function()
        return picker.__completed > completed
      end, 10)
      eq(1, picker.manager:num_results())
    end)
  end)

  it("keeps entries matching file_ignore_patterns out", function()
    exec_lua(function()
      local h = require("tests.picker_helpers")
      local eq = require("test.assert").eq
      require("telescope.pickers")
        .new({ file_ignore_patterns = { "^x" } }, {
          finder = require("telescope.finders").new_table({ results = { "ab", "xab", "abc" } }),
          sorter = require("telescope.sorters").get_fzy_sorter(),
        })
        :find()
      local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
      picker.__completed = 0
      picker:register_completion_callback(function(p)
        p.__completed = p.__completed + 1
      end)
      h.type(picker, "ab")
      eq({ 2, 2 }, { picker.manager:num_results(), picker.stats.processed })
      -- deleting a character scores all entries again
      local completed = picker.__completed
      picker:set_prompt("a")
      vim.wait(5000, function()
        return picker.__completed > completed
      end, 10)
      eq({ 2, 2 }, { picker.manager:num_results(), picker.stats.processed })
    end)
  end)
end)
