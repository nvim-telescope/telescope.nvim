-- Runs the specs with Nvim's test harness (test/harness.lua from the Nvim repo, see Makefile).
-- Usage: nvim --clean -l tests/runner.lua <dir with test/harness.lua> <spec file or directory>...
local deps = assert(_G.arg[1], "usage: nvim --clean -l tests/runner.lua <test deps> <path>...")
package.path = table.concat({ deps .. "/?.lua", deps .. "/test/?.lua" }, ";") .. ";" .. package.path

vim.opt.rtp:prepend(".")
vim.o.showmode = false
vim.cmd.runtime({ "plugin/telescope.lua", bang = true })

local exit_code = require("test.harness").main({ unpack(_G.arg, 2) })
io.stdout:flush()
io.stderr:flush()
os.exit(exit_code)
