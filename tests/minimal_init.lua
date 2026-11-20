-- Init file of the Nvim under test (started by tests/sut.lua).
vim.opt.rtp:prepend(".")
-- for require("tests.picker_helpers") in code run by the specs
package.path = "./?.lua;" .. package.path
vim.o.showmode = false
vim.o.swapfile = false
vim.cmd.runtime({ "plugin/telescope.lua", bang = true })
