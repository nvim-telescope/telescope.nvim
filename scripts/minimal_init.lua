vim.o.rtp = os.getenv "PLENTEST" .. ",.,../plenary.nvim," .. vim.o.rtp
vim.o.rtp = ",../tree-sitter-lua," .. vim.o.rtp

-- The test runner loads this file before it starts one process per spec file in parallel. Create the
-- data directory (which exists in practice) here, so the test processes don't race to create it.
vim.fn.mkdir(vim.fn.stdpath "data", "p")

vim.cmd.runtime { "plugin/telescope", bang = true }
vim.g.telescope_test_delay = 100
