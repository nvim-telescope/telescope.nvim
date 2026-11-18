-- Starts the Nvim under test ($NVIM_PRG, see Makefile) for the specs of a file; the specs talk to it
-- with `exec_lua()`, `api` and `fn` from test/functional/testnvim.lua.
local t = require("test.testutil")
local n = require("test.functional.testnvim")()

local M = {}

--- Start the Nvim under test before the first test of the current spec file.
function M.setup()
  t.setup(function()
    n.clear({
      merge = false,
      args = { "--clean", "-u", "tests/minimal_init.lua", "--embed", "--headless" },
    })
  end)
end

return M
