local t = require("test.harness")
local assert = require("test.assert")
local describe, it, after_each = t.describe, t.it, t.after_each

if require("telescope.utils").iswin then
  return
end

local h = require("tests.helpers")
local eq = assert.eq

describe("finders.new_oneshot_job", function()
  after_each(h.cleanup)

  it("returns a last line without trailing newline", function()
    require("telescope.pickers")
      .new({}, {
        finder = require("telescope.finders").new_oneshot_job({ "printf", "a\\nb\\nlast" }),
        sorter = require("telescope.sorters").get_fzy_sorter(),
      })
      :find()
    local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
    vim.wait(5000, function()
      return picker.finder.results and #picker.finder.results >= 3
    end, 10)
    eq(
      { "a", "b", "last" },
      vim.tbl_map(function(e)
        return e.value
      end, picker.finder.results)
    )
  end)

  it("gives results for a new prompt while the command still runs", function()
    require("telescope.pickers")
      .new({}, {
        finder = require("telescope.finders").new_oneshot_job({ "sh", "-c", "printf 'alpha\\nbeta\\n'; exec sleep 5" }),
        sorter = require("telescope.sorters").get_fzy_sorter(),
      })
      :find()
    local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
    vim.wait(2000, function()
      return #picker.finder.results >= 2
    end, 10)
    picker:set_prompt("bet")
    vim.wait(2000, function()
      return picker.manager:num_results() == 1
    end, 10)
    eq({ 1, "beta" }, { picker.manager:num_results(), picker.manager:get_entry(1).value })
  end)
end)
