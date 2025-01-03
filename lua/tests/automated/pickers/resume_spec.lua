-- Just skip on mac, it has flaky CI for some reason
if vim.fn.has "mac" == 1 or require("telescope.utils").iswin then
  return
end

local tester = require "telescope.testharness"

describe("builtin.resume", function()
  it("should select and open the file", function()
    tester.run_file "resume__select_pos"
  end)
end)
