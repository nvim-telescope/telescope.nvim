-- Loaded by the Nvim test harness (`--helper`, see Makefile) before running the specs.
-- The specs run their code in a separate Nvim, the Nvim under test ($NVIM_PRG), see tests/sut.lua.

-- The Makefile passes paths relative to the repo; the Nvim under test inherits the environment.
vim.env.NVIM_PRG = vim.fs.abspath(assert(vim.env.NVIM_PRG, "NVIM_PRG: the Nvim under test"))
vim.env.NVIM_LOG_FILE = vim.env.NVIM_LOG_FILE and vim.fs.abspath(vim.env.NVIM_LOG_FILE)
-- The Nvim under test loads the handler of `exec_lua()` (`test.functional.testnvim.exec_lua`) from the host.
local harness = assert(package.searchpath("test.harness", package.path))
vim.env.LUA_PATH = vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(harness))) .. "/?.lua;;"

-- Keep the RPC client and its session state loaded across spec files.
require("test.functional.testnvim")()

-- Don't let the Nvim under test inherit the runtime files of the Nvim running the harness.
vim.env.VIMRUNTIME = nil
vim.env.VIM = nil
