local tester = require "telescope.testharness"

describe("builtin.oldfiles", function()
	it("should escape tilde", function()
    tester.run_file "oldfiles__escape_tilde"
	end)
end)
