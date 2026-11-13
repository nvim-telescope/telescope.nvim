local t = require "test.harness"
local assert = require "test.assert"
local describe, it, after_each = t.describe, t.it, t.after_each

local h = require "tests.helpers"

describe("mappings", function()
  after_each(h.cleanup)

  it("may map modes other than normal and insert", function()
    h.picker("find_files", {
      cwd = "lua/telescope/pickers",
      attach_mappings = function(_, map)
        map("x", "<C-a>", function() end)
        return true
      end,
    })
    assert.eq("<C-A>", vim.fn.maparg("<C-a>", "x", false, true).lhs)
  end)
end)
