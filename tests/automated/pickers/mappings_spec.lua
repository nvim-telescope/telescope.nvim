local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each, eq = t.describe, t.it, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("mappings", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("may map modes other than normal and insert", function()
    eq(
      "<C-A>",
      exec_lua(function()
        require("tests.picker_helpers").picker("find_files", {
          cwd = "lua/telescope/pickers",
          attach_mappings = function(_, map)
            map("x", "<C-a>", function() end)
            return true
          end,
        })
        return vim.fn.maparg("<C-a>", "x", false, true).lhs
      end)
    )
  end)
end)
