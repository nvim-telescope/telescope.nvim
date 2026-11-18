local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each, eq = t.describe, t.it, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

if t.is_os("win") then
  return
end

sut.setup()

describe("finders.new_oneshot_job", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("returns a last line without trailing newline", function()
    eq(
      { "a", "b", "last" },
      exec_lua(function()
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
        return vim.tbl_map(function(e)
          return e.value
        end, picker.finder.results)
      end)
    )
  end)

  it("gives results for a new prompt while the command still runs", function()
    eq(
      { 1, "beta" },
      exec_lua(function()
        require("telescope.pickers")
          .new({}, {
            finder = require("telescope.finders").new_oneshot_job({
              "sh",
              "-c",
              "printf 'alpha\\nbeta\\n'; exec sleep 5",
            }),
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
        return { picker.manager:num_results(), picker.manager:get_entry(1).value }
      end)
    )
  end)
end)
