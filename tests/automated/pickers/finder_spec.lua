local t = require "test.harness"
local assert = require "test.assert"
local describe, it, after_each = t.describe, t.it, t.after_each

local h = require "tests.helpers"

describe("finders", function()
  after_each(h.cleanup)

  it("may wait with vim.async", function()
    local finder = setmetatable({ close = function() end }, {
      __call = function(_, _, process_result, process_complete)
        vim.async.sleep(1)
        process_result { value = "waited", ordinal = "waited", display = "waited" }
        process_complete()
      end,
    })
    local picker = require("telescope.pickers").new({}, { finder = finder })
    picker.__completed = 0
    picker:register_completion_callback(function(p)
      p.__completed = p.__completed + 1
    end)
    picker:find()
    vim.wait(1000, function()
      return picker.__completed > 0
    end, 1)
    assert.eq("waited", picker.manager:get_entry(1).value)
  end)

  it("notifies a finder error", function()
    local notified
    local notify = vim.notify
    vim.notify = function(msg)
      notified = msg
    end
    local finder = setmetatable({ close = function() end }, {
      __call = function()
        vim.async.sleep(1)
        error "broken"
      end,
    })
    require("telescope.pickers").new({}, { finder = finder }):find()
    vim.wait(1000, function()
      return notified ~= nil
    end, 1)
    vim.notify = notify
    assert(notified and notified:find "Finder failed: .*broken")
  end)
end)
