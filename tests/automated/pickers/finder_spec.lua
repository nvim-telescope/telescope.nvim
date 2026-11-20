local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, after_each, eq = t.describe, t.it, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("finders", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("may wait with vim.async", function()
    eq(
      "waited",
      exec_lua(function()
        local finder = setmetatable({ close = function() end }, {
          __call = function(_, _, process_result, process_complete)
            vim.async.sleep(1)
            process_result({ value = "waited", ordinal = "waited", display = "waited" })
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
        return picker.manager:get_entry(1).value
      end)
    )
  end)

  it("notifies a finder error", function()
    local notified = exec_lua(function()
      local notified
      local notify = vim.notify
      vim.notify = function(msg)
        notified = msg
      end
      local finder = setmetatable({ close = function() end }, {
        __call = function()
          vim.async.sleep(1)
          error("broken")
        end,
      })
      require("telescope.pickers").new({}, { finder = finder }):find()
      vim.wait(1000, function()
        return notified ~= nil
      end, 1)
      vim.notify = notify
      return notified
    end)
    t.matches("Finder failed: .*broken", notified)
  end)
end)
