local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each = t.describe, t.it, t.after_each
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("pickers prompt", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("keeps the prefix highlight of refresh{ new_prefix } while typing", function()
    exec_lua(function()
      local h = require("tests.picker_helpers")
      local eq = require("test.assert").eq
      require("telescope.pickers")
        .new({}, { finder = require("telescope.finders").new_table({ results = { "ab", "b" } }) })
        :find()
      local picker = require("telescope.actions.state").get_current_picker(vim.api.nvim_get_current_buf())
      picker.__completed = 0
      picker:register_completion_callback(function(p)
        p.__completed = p.__completed + 1
      end)
      picker:refresh(nil, { new_prefix = { "new> ", "ErrorMsg" } })
      h.type(picker, "a")
      eq("new> a", h.prompt(picker))

      local ns = vim.api.nvim_get_namespaces().telescope_prompt_prefix
      local marks = vim.api.nvim_buf_get_extmarks(picker.prompt_bufnr, ns, 0, -1, { details = true })
      eq(1, #marks)
      eq({ "ErrorMsg", 5 }, { marks[1][4].hl_group, marks[1][4].end_col })
    end)
  end)
end)
