local h = require "tests.helpers"
local eq = assert.eq

describe("pickers narrowing", function()
  after_each(h.cleanup)

  it("doesn't bring back entries deleted from the finder", function()
    require("telescope.pickers")
      .new({}, {
        finder = require("telescope.finders").new_table { results = { "ab", "ac", "bc" } },
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
